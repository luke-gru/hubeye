module Server
  # standard lib.
  require 'socket'
  require 'yaml'

  # vendor
  begin
    require 'octopi'
  rescue LoadError
    if require 'rubygems'
      retry
    else
      abort 'Octopi is needed to run hubeye. Gem install octopi'
    end
  end

  # hubeye
  require "config/parser"
  require "log/logger"
  require "notification/notification"
  require "hooks/git_hooks"
  require "hooks/executer"
  require "helpers/time"
  include Helpers::Time
  include Octopi

  CONFIG_FILE = ENV['HOME'] + "/.hubeye/hubeyerc"
  CONFIG = {}
  # find Desktop notification system

  # CONFIG options: defined in ~/.hubeye/hubeyerc
  #
  # Option overview:
  #
  # CONFIG[:oncearound]: 30 (seconds) is the default amount of time for looking
  # for changes in every single repository. If tracking lots of repos,
  # it might be a good idea to increase the value, or hubeye will cry
  # due to overwork, fatigue and general anhedonia.
  #
  # hubeyerc format: oncearound: 1000
  #
  # CONFIG[:username] is the username used when not specified:
  # when set to 'hansolo'
  # >rails
  # would track https://www.github.com/hansolo/rails
  # but a full URI path won't use CONFIG[:username]
  # >rails/rails
  # would track https://www.github.com/rails/rails
  #
  # hubeyerc format: username: hansolo
  ::Hubeye::Config::Parser.new(CONFIG_FILE) do |c|
    CONFIG[:username]       = c.username || 'luke-gru'
    CONFIG[:oncearound]     = c.oncearound || 60
    CONFIG[:load_repos]     = c.load_repos || []
    CONFIG[:load_hooks]     = c.load_hooks || []
    CONFIG[:default_track]  = c.default_track || nil
    # returns true or false if defined in hubeyerc
    CONFIG[:notification_wanted] = case c.notification_wanted
                          when false
                            false
                          when true
                            true
                          when nil
                            # default is true if not defined in hubeyerc
                            true
                          end
  end

  CONFIG[:desktop_notification] = (CONFIG[:notification_wanted] ?
                                  Notification::Finder.find_notify : nil)

  class InputError < StandardError; end

  def start(port, options={})
    listen(port)
    setup_env(options)
    loop do
      catch(:next) do
        not_connected() unless @remote_connection
        get_input(@socket)
        puts @input if @debug
        parse_input()
        parse_doc()
        @username = CONFIG[:username]
      end
    end
  end

  # Listen on port (2000 is the default)
  def listen(port)
    @server = TCPServer.open(port)
  end


  def setup_env(options={})
    @daemonized = options[:daemon]
    @sockets = [@server]  # An array of sockets we'll monitor
    if CONFIG[:default_track].nil?
      # will be array of 2-element arrays that contain the
      # tracked repo name [0] and hash of latest sha and latest commit object
      # for that repo [1]
      # Example:
      # [ ['luke-gru/hubeye', {:sha1 => 90j93r0rf389, :commit => <#Commit Object>}], [..., ...] ]
      @hubeye_tracker = []
    else
      # default tracking arrays (hubeyerc configurations)
      @hubeye_tracker = CONFIG[:default_track]
    end
    setup_hubeye_singleton_methods

    if CONFIG[:load_hooks].empty?
      # do nothing (the hooks hash is only assigned when needed)
    else
      hooks_ary = CONFIG[:load_hooks].dup
      load_hooks_or_repos :internal_input => hooks_ary,
                          :internal_input_hooks => true
    end

    if CONFIG[:load_repos].empty?
      # do nothing
    else
      repos_ary = CONFIG[:load_repos].dup
      load_hooks_or_repos :internal_input => repos_ary,
                          :internal_input_repos => true
    end
    # @username changes if input includes a '/' when removing and adding
    # tracked repos.
    @username = CONFIG[:username]
    @remote_connection = false
  end

  class ::Array
    include Octopi
    class NotTrackerElementError < TypeError ; end

    def extract_old_and_new
      if length != 2
        raise NotTrackerElementError.new "#{self} is not a hubeye_tracker element"
      else
        p self
        tracked_repo, tracked_sha = self[0], self[1][:sha1]
        username, repo_name = tracked_repo.split '/'
        gh_user = User.find(username)
        repo = gh_user.repository repo_name
      end
      [tracked_sha, repo]
    end
  end

  def setup_hubeye_singleton_methods
    @hubeye_tracker.singleton_class.class_eval do
      define_method :append_or_replace! do |repo_name, new_commit_obj|
        match = nil
        map do |e|
          if e[0] == repo_name
            match = true
            e[1][:sha1]   = new_commit_obj.id
            e[1][:commit] = new_commit_obj
          else
            e
          end
        end
        if match
          return true
        else
          self << [repo_name, {:sha1   => new_commit_obj.id,
            :commit => new_commit_obj}]
          return nil
        end
      end
    end
    @hubeye_tracker.singleton_class.class_eval do
      define_method :eyeing do
        (ary = []).tap do
          each do |e|
            ary << e[0]
          end
        end
      end
    end
    @hubeye_tracker.singleton_class.class_eval do
      define_method :rm_repo do |repo_name|
        match = nil
        map do |e|
          if e[0] == repo_name
            match = true
            repo_name.delete(e)
          else
            e
          end
        end
        match
      end
    end
  end


  def not_connected
    # if no client is connected, but the commits array contains repos
    if @sockets.size == 1 and !@hubeye_tracker.empty?

      while @remote_connection == false
        @hubeye_tracker.each do |ary|
          old_sha, new_repo = ary.extract_old_and_new
          new_commit = new_repo.commits.first
          puts new_commit.id
          if new_commit.id == old_sha
            CONFIG[:oncearound].times do
              sleep 1
              @remote_connection = client_ready(@sockets) ? true : false
              break if @remote_connection
            end
          else
            # There was a change to a tracked repository.
            repo       = new_repo.name
            commit_msg = new_commit.message
            committer  = new_commit.author['name']
            # notify of change to repository
            # if they have a Desktop notification
            # library installed
            change_msg = "Repo #{repo} has changed\nNew commit: #{commit_msg} => #{committer}"
            case CONFIG[:desktop_notification]
            when "libnotify"
              Autotest::GnomeNotify.notify("Hubeye", change_msg)
              Logger.log_change(repo, commit_msg, committer)
            when "growl"
              Autotest::Growl.growl("Hubeye", change_msg)
              Logger.log_change(repo, commit_msg, committer)
            when nil
              if @daemonized
                Logger.log_change(repo, commit_msg, committer)
              else
                Logger.log_change(repo, commit_msg, committer, :include_terminal => true)
              end
            end
            # execute any hooks for that repository
            unless @hook_cmds.nil? || @hook_cmds.empty?
              if @hook_cmds[repo]
                hook_cmds = @hook_cmds[repo].dup
                dir = (hook_cmds.include?('/') ? hook_cmds.shift : nil)

                # execute() takes [commands], {options} where
                # options = :directory and :repo
                Hooks::Command.execute(hook_cmds, :directory => dir, :repo => repo)
              end
            end
            @hubeye_tracker.append_or_replace!(repo, new_commit)
          end
        end
        redo unless @remote_connection
      end # end of (while remote_connection == false)
    end
    client_connect(@sockets)
  end


  def client_ready(sockets)
    select(sockets, nil, nil, 2)
  end
  private :client_ready


  def client_connect(sockets)
    ready = select(sockets)
    readable = ready[0]            # These sockets are readable
    readable.each do |socket|      # Loop through readable sockets
      if socket == @server         # If the server socket is ready
        client = @server.accept    # Accept a new client
        @socket = client           # From here on in referred to as @socket
        sockets << @socket         # Add it to the set of sockets
        # Inform the client of connection
        if !@hubeye_tracker.empty?
          @socket.puts "Hubeye running on #{Socket.gethostname}\nTracking:#{@hubeye_tracker.eyeing.join ', '}"
        else
          @socket.puts "Hubeye running on #{Socket.gethostname}"
        end

        if !@daemonized
          puts "Client connected at #{NOW}"
        end

        @socket.flush
        # And log the fact that the client connected
        if @still_logging == true
          # if the client quit, do not wipe the log file
          Logger.log "Accepted connection from #{@socket.peeraddr[2]} (#{NOW})"
        else
          # wipe the log file and start anew
          Logger.relog "Accepted connection from #{@socket.peeraddr[2]} (#{NOW})"
        end
        Logger.log "local:  #{@socket.addr}"
        Logger.log "peer :  #{@socket.peeraddr}"
      end
    end
  end


  def get_input(socket)
    @input = socket.gets  # Read input from the client
    @input.chop! unless @input.nil?  # Trim client's input
    # If no input, the client has disconnected
    if !@input
      Logger.log "Client on #{socket.peeraddr[2]} disconnected."
      @sockets.delete(socket)  # Stop monitoring this socket
      socket.close  # Close it
      throw(:next)  # And go on to the next
    end
  end
  private :get_input


  def parse_input
    @input.strip!; @input.downcase!
    if parse_quit()
    elsif parse_shutdown()
    elsif save_hooks_or_repos()
    elsif load_hooks_or_repos()
      # parse_hook must be before parse_fullpath_add for the moment
    elsif parse_hook()
    elsif hook_list()
    elsif tracking_list()
    elsif parse_pwd()
    elsif parse_empty()
    elsif parse_remove()
    elsif parse_fullpath_add()
    elsif parse_add()
    else
      raise InputError "Invalid input #{@input}"
    end
  end


  def parse_quit
    if @input =~ /\Aquit|exit\Z/  # If the client asks to quit
      @socket.puts("Bye!")  # Say goodbye
      Logger.log "Closing connection to #{@socket.peeraddr[2]}"
      @remote_connection = false
      if !@hubeye_tracker.empty?
        Logger.log "Tracking: #{@hubeye_tracker.eyeing.join ', '}"
      end
      Logger.log "" # to look pretty when multiple connections per loop
      @sockets.delete(@socket)  # Stop monitoring the socket
      @socket.close  # Terminate the session
      # still_logging makes the server not wipe the log file
      @still_logging = true
    else
      return
    end
    throw(:next)
  end


  def parse_shutdown
    if @input == "shutdown"
      # local
      Logger.log "Closing connection to #{@socket.peeraddr[2]}"
      Logger.log "Shutting down... (#{NOW})"
      Logger.log ""
      Logger.log ""
      # peer
      @socket.puts("Shutting down server")
    else
      return
    end
    shutdown
  end


  def shutdown
    @sockets.delete(@socket)
    @socket.close
    exit
  end


  def parse_hook
    if %r{hook add} =~ @input
      hook_add
    else
      return
    end
  end


  # @hook_cmds:
  # repo is the key, value is array of directory and commands. First element
  # of array is the local directory for that remote repo, rest are commands
  # related to hooks called on change of commit message (with plans to change
  # that to commit SHA reference) of the remote repo
  def hook_add
    @input.gsub!(/diiv/, '/')
    # make match-$globals parse input
    @input =~ /add ([^\/]+\/\w+) (dir: (\S*) )?cmd: (.*)\Z/
      @hook_cmds ||= {}
    if $1 != nil && $4 != nil
      if @hook_cmds[$1]
        @hook_cmds[$1] << $4
      elsif $2 != nil
        @hook_cmds[$1] = [$3, $4]
      else
        @hook_cmds[$1] = [$4]
      end
      @socket.puts("Hook added")
    else
      @socket.puts("Format: 'hook add user/repo [dir: /my/dir/repo ] cmd: git pull origin'")
    end
    throw(:next)
  end
  private :hook_add


  def save_hooks_or_repos
    if @input =~ %r{\A\s*save hook(s?) as (.+)\Z}
      if !@hook_cmds.nil? && !@hook_cmds.empty?
        File.open("#{ENV['HOME']}/.hubeye/hooks/#{$2}.yml", "w") do |f_out|
          ::YAML.dump(@hook_cmds, f_out)
        end
        @socket.puts("Saved hook#{$1} as #{$2}")
      else
        @socket.puts("No hook#{$1} to save")
      end
      throw(:next)
    elsif @input =~ %r{\A\s*save repo(s?) as (.+)\Z}
      if !@hubeye_tracker.empty?
        File.open("#{ENV['HOME']}/.hubeye/repos/#{$2}.yml", "w") do |f_out|
          ::YAML.dump(@hubeye_tracker.eyeing, f_out)
        end
        @socket.puts("Saved repo#{$1} as #{$2}")
      else
        @socket.puts("No remote repos are being tracked")
      end
      throw(:next)
    else
      return
    end
  end


  # options are internal input: can be true or falselike.
  # When falselike (nil is default), it outputs to the client socket.
  # When truelike (such as when used internally), it outputs nothing.
  def load_hooks_or_repos(options={})
    opts = {:internal_input => nil, :internal_input_hooks => nil,
      :internal_input_repos => nil}.merge options
    if opts[:internal_input].nil?
      load_hooks_repos_from_terminal_input
    elsif opts[:internal_input]
      input = opts[:internal_input]
      if opts[:internal_input_hooks]
        load_hooks_from_internal_input(input)
      elsif opts[:internal_input_repos]
        load_repos_from_internal_input(input)
      end
    end
  end

  def load_hooks_repos_from_terminal_input
    if @input =~ %r{\A\s*load hook(s?) (.+)\Z}
      hookfile = "#{ENV['HOME']}/.hubeye/hooks/#{$2}.yml"

      # establish non block-local scope
      newhooks = nil

      if File.exists?(hookfile)
        File.open(hookfile) do |f|
          newhooks = ::YAML.load(f)
        end
        @hook_cmds ||= {}
        @hook_cmds = newhooks.merge(@hook_cmds)
        @socket.puts("Loaded #{$1} #{$2}")
      else
        @socket.puts("No #{$1} file to load from")
      end
      throw(:next)
    elsif @input =~ %r{\A\s*load repo(s)? (.+)\Z}
      if File.exists? repo_file = "#{ENV['HOME']}/.hubeye/repos/#{$2}.yml"
        newrepos = nil
        File.open(repo_file) do |f|
          newrepos = ::YAML.load(f)
        end

        if !newrepos
          @socket.puts "Unable to load #{$2}: empty file"
          throw(:next)
        end
        # newrepos is an array of repos to be tracked
        newrepos.each do |e|
          # append the repo name and the commit hash to the hubeye tracker
          # array, then inform the client of the newest commit message
          username, repo = e.split '/'
          gh_user = User.find(username)
          gh_repo = gh_user.repository repo
          new_commit = gh_repo.commits.first
          @hubeye_tracker.append_or_replace!(e, new_commit)
        end
        @socket.puts "Loaded #{$2}.\nTracking:\n#{@hubeye_tracker.eyeing.join ', '}"
      else
        # no repo file with that name
        @socket.puts("No file to load from")
      end
      throw(:next)
    end
    return
  end

  def load_hooks_from_internal_input(input)
    if input.respond_to? :to_a
      input = input.to_a
      input.each do |hook|
        hookfile = "#{ENV['HOME']}/.hubeye/hooks/#{hook}.yml"
        newhook = nil
        if File.exists?(hookfile)
          File.open(hookfile) do |f|
            newhook = ::YAML.load(f)
          end
          @hook_cmds ||= {}
          @hook_cmds = newhook.merge(@hook_cmds)
        else
          # do nothing because of no extra processing after this, newhook
          # can stay nil if the hook file doesn't exist
        end
      end
    else
      raise ArgumentError.new "#{input} must be array-like"
    end
  end

  def load_repos_from_internal_input(input)
    if input.respond_to? :to_a
      input = input.to_a
      newrepos = []
      input.each do |repo|
        repofile = "#{ENV['HOME']}/.hubeye/repos/#{repo}.yml"
        newrepo = nil
        if File.exists?(repofile)
          File.open(repofile) do |f|
            newrepo = ::YAML.load(f)
          end
          # empty repo file, go to next repo file in the array
          if !newrepo
            next
          else
            # append the newrepo array to the newrepos array
            newrepos << newrepo
          end
        else
          # file doesn't exist, next repo file
          next
        end
      end # end of input#each
      # flatten the newrepos array because it contains arrays
      newrepos.flatten!
      newrepos.each do |e|
        username, repo = e.split '/'
        gh_user = User.find(username)
        gh_repo = gh_user.repository repo
        new_commit = gh_repo.commits.first
        @hubeye_tracker.append_or_replace!(e, new_commit)
      end
    else
      raise ArgumentError.new "#{input} must be array-like"
    end
  end

  def hook_list
    if @input =~ %r{hook list}
      unless @hook_cmds.nil? || @hook_cmds.empty?
        format_string = ""
        @hook_cmds.each do |repo, ary|
          remote = repo
          if ary.first.include? '/'
            local = ary.first
            cmds  = ary[1..-1]
          else
            cmds = ary
            local = "N/A"
          end
          format_string += <<-EOS
remote: #{remote}
  dir : #{local}
  cmds: #{cmds.each {|cmd| print cmd + ' ' }} \n
  EOS
        end
        @socket.puts(format_string)
        @socketspoke = true
      end
    else
      return
    end
    @socket.puts("No hooks") unless @socketspoke
    @socketspoke = nil
    throw(:next)
  end


  # show the client what repos (with commit messages)
  # they're tracking
  def tracking_list
    if @input =~ /\Atracking\s*\Z/
      list = @hubeye_tracker.eyeing.join ', '
      @socket.puts(list)
      throw(:next)
    else
      return
    end
  end


  # This means the user pressed '.' in the client,
  # wanting to track the pwd repo. The period is replaced
  # by 'pwd' in the client application and sent to @input because of
  # problems with the period getting stripped in TCP transit. The name
  # of the client's present working directory comes right after the 'pwd'.
  # Typing '.' in the client only works (ie: begins tracking the remote repo)
  # if the root directory of the git repository has the same name as one of
  # the user's github repositories.
  def parse_pwd
    if @input.match(/^pwd/)
      @repo_name = @input[3..-1]
    else
      return
    end
    return true
  end


  def parse_empty
    if @input == ''
      @socket.puts("")
      throw(:next)
    else
      return
    end
  end


  # Like the method parse_pwd, in which the client application replaces
  # the '.' with 'pwd' and sends that to this server instead, parse_remove
  # does pretty much the same thing with '/'. This is because of the slash
  # getting stripped in TCP transit. Here, the slash is replaced with 'diiv',
  # as this is unlikely to be included anywhere in a real username/repository
  # combination (or is it... duh duh DUUUUHH)
  # p.s. no it isn't
  def parse_remove
    if %r{\Arm ([\w-](diiv)?[\w-]*)\Z} =~ @input
      if $1.include?("diiv")
        @username, @repo_name = $1.split('diiv')
      else
        @username, @repo_name = "#{@username}/#{$1}".split('/')
      end
      begin
        rm = @ary_commits_repos.rm_repo("#{@username}/#{@repo_name}")
        if rm
          @socket.puts("Stopped watching repository #{@username}/#{@repo_name}")
          sleep 0.5
          throw(:next)
        else
          @socket.puts("Repository #{@username}/#{@repo_name} not currently being watched")
          throw(:next)
        end
      rescue
        @socket.puts($!)
        throw(:next)
      end
    else
      return
    end
  end


  def parse_fullpath_add
    if @input.include?('diiv')
      # includes a '/', such as rails/rails, but in the adding to tracker context
      @username, @repo_name = @input.split('diiv')
    else
      return
    end
    return true
  end


  # if the input is not the above special scenarios
  def parse_add
    @repo_name = @input
  end

  def parse_doc
    @full_repo_name = "#{@username}/#{@repo_name}"
    begin
      gh_user = User.find(@username)
      gh_repo = gh_user.repository @repo_name
    rescue ArgumentError, Octopi::NotFound
      #Octopi library's User.find ArgumentError
      @socket.puts "Not a Github repository name"
      throw :next
    end
    new_commit = gh_repo.commits.first
    replace = @hubeye_tracker.append_or_replace!(@full_repo_name, new_commit)
    # new repo to track
    if !replace
      # get commit info
      commit_msg = new_commit.message
      committer  = new_commit.author['name']
      msg =  "#{commit_msg}\n=> #{committer}"
      url = "https://www.github.com#{new_commit.url[0..-30]}"
      # log the fact that the user added a repo to be tracked
      Logger.log("Added to tracker: #{@full_repo_name} (#{NOW})")
      # show the user, via the client, the info and commit msg for the commit
      @socket.puts("#{msg}\n#{url}")

      # new commit to tracked repo
    elsif !replace
      begin
        # log to the logfile and tell the client
        if @daemonized
          Logger.log_change(@full_repo_name, commit_msg, committer,
                            :include_socket => true)
        else
          Logger.log_change(@full_repo_name, commit_msg, committer,
                            :include_socket => true, :include_terminal => true)
        end
      rescue
        @socket.puts($!)
      end
    else
      # no change to the tracked repo
      @socket.puts("Repository #{@full_repo_name} has not changed")
    end
  end

end # of Server module

class HubeyeServer
  include Server

  def initialize(debug=true)
    @debug = debug
  end

end

