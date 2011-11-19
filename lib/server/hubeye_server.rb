class Hubeye
  module Server
    attr_accessor :remote_connection
    attr_reader :socket, :sockets, :session

    # standard lib.
    require 'socket'
    require 'yaml'
    require 'json'
    require 'open-uri'
    # hubeye
    require "config/parser"
    require "log/logger"
    require "notification/notification"
    require "hooks/git_hooks"
    require "hooks/executer"
    require "helpers/time"
    include Helpers::Time

    CONFIG_FILE = ENV['HOME'] + "/.hubeye/hubeyerc"
    CONFIG = {}
    # find Desktop notification system

    # CONFIG options: defined in ~/.hubeye/hubeyerc
    #
    # Option overview:
    #
    # CONFIG[:oncearound]: 60 (seconds) is the default amount of time for looking
    # for changes in every single repository. If tracking lots of repos,
    # it might be a good idea to increase the value, or hubeye will cry
    # due to overwork, fatigue and general anhedonia.
    #
    # hubeyerc format => oncearound: 1000
    #
    # CONFIG[:username] is the username used when not specified.
    # hubeyerc format => username: 'hansolo'
    # when set to 'hansolo'
    # >rails
    # would track https://www.github.com/hansolo/rails
    # but a full URI path won't use CONFIG[:username]
    # >rails/rails
    # would track https://www.github.com/rails/rails
    Config::Parser.new(CONFIG_FILE) do |c|
      CONFIG[:username]       = c.username ||
        `git config --get-regexp github`.split(' ').last
      CONFIG[:oncearound]     = c.oncearound || 60
      CONFIG[:load_repos]     = c.load_repos || []
      CONFIG[:load_hooks]     = c.load_hooks || []
      CONFIG[:default_track]  = c.default_track || nil

      CONFIG[:notification_wanted] = if c.notification_wanted.nil?
                                       true
                                     else
                                       c.notification_wanted
                                     end
    end

    CONFIG[:desktop_notification] = Notification::Finder.find_notify if
    CONFIG[:notification_wanted]

    class Session

      attr_writer :tracker, :repo_name, :username, :hooks
      attr_reader :repo_name, :username

      def initialize
        setup_singleton_methods
      end

      def tracker
        @tracker ||= {}
      end

      def hooks
        @hooks ||= {}
      end

      def load options={}
        opts = {:hooks => nil, :repos => nil}.merge options
        if opts[:hooks]
        elsif opts[:repos]
        else
          raise ArgumentError
        end
      end

      def reset
        reset_username
        reset_repo_name
      end

      private
      def reset_username
        self.username = CONFIG[:username]
      end

      def reset_repo_name
        self.repo_name = ""
      end

      def setup_singleton_methods
        tracker.singleton_class.class_eval do
          def add_or_replace! repo_name, new_sha
            if keys.include? repo_name and self[repo_name] == new_sha
              return
            elsif keys.include? repo_name
              ret = {:replace => true}
            else
              ret = {:add => true}
            end
            self[repo_name] = new_sha
            ret
          end
        end
      end

    end # end of Session class

    def start(port, options={})
      listen(port)
      setup_env(options)
      loop do
        look_for_changes unless @remote_connection
        strategy = Strategy.new(self)
        strategy.call
        @session.reset
      end
    end

    # Listen on port (2000 is the default)
    def listen(port)
      @server = TCPServer.open(port)
    end

    def setup_env(options={})
      @daemonized = options[:daemon]
      @sockets = [@server]  # An array of sockets we'll monitor
      @session = Session.new
      unless CONFIG[:default_track].nil?
        newly_tracked = {}
        CONFIG[:default_track].each {|repo| newly_tracked.merge! track(repo)}
        @session.tracker.merge! newly_tracked
      end
      unless CONFIG[:load_hooks].empty?
        hooks = CONFIG[:load_hooks].dup
        @session.load :hooks => hooks
      end
      unless CONFIG[:load_repos].empty?
        repos = CONFIG[:load_repos].dup
        @session.load :repos => repos
      end
      @session.username = CONFIG[:username]
      @remote_connection = false
    end

    # options: :short, :latest, :full (all boolean)
    def track(repo, options)
      opts = {:short => true}.merge options
      if repo.include? '/'
        username, repo_name = repo.split '/'
        full_repo_name = repo
      else
        username, repo_name = @session.username, repo
        full_repo_name = "#{username}/#{repo_name}"
      end
      hist = nil
      begin
        open "https://api.github.com/repos/#{username}/" \
        "#{repo_name}/commits" do |f|
          hist = JSON.parse f.read
        end
      rescue
        @socket.puts "Not a Github repository name"
        return
      end
      if opts[:short]
        {full_repo_name => hist.first['sha']}
      elsif opts[:latest]
        {full_repo_name => hist.first}
      else
        {full_repo_name => hist}
      end
    end
    private :track

    def look_for_changes
      # if no client is connected, but the commits array contains repos
      if @sockets.size == 1 and !@session.tracker.empty?

        while @remote_connection == false
          sleep_amt = CONFIG[:oncearound] / @session.tracker.length
          @session.tracker.each do |k,v|
            start_time = Time.now
            new_info = track(k, :latest => true)
            api_time = (Time.now - start_time).to_i
            if new_info[k] == v
              (sleep_amt - api_time).times do
                sleep 1
                @remote_connection = client_ready(@sockets) ? true : false
                break if @remote_connection
              end
            else
              # There was a change to a tracked repository.
              full_repo_name = new_info.keys.first
              commit_msg     = new_info['message']
              committer      = new_info['author']['name']
              change_msg = "Repo #{full_repo_name} has changed\nNew commit: " \
                "#{commit_msg}\n=> #{committer}"
              case CONFIG[:desktop_notification]
              when "libnotify"
                Autotest::GnomeNotify.notify("Hubeye", change_msg)
                Logger.log_change(full_repo_name, commit_msg, committer)
              when "growl"
                Autotest::Growl.growl("Hubeye", change_msg)
                Logger.log_change(full_repo_name, commit_msg, committer)
              when nil
                if @daemonized
                  Logger.log_change(full_repo_name, commit_msg, committer)
                else
                  Logger.log_change(full_repo_name, commit_msg, committer, :include_terminal => true)
                end
              end
              # execute any hooks for that repository
              unless @session.hooks.nil? || @session.hooks.empty?
                if @session.hooks[full_repo_name]
                  hook_cmds = @session.hooks[full_repo_name].dup
                  dir = (hook_cmds.include?('/') ? hook_cmds.shift : nil)
                  # execute() takes [commands], {options} where
                  # options = :directory and :repo
                  Hooks::Command.execute(hook_cmds, :directory => dir, :repo => repo)
                end
              end
              @session.tracker.add_or_replace!(full_repo_name, new_commit)
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
      readable = ready[0]
      readable.each do |socket|
        if socket == @server
          client = @server.accept
          @socket = client
          sockets << @socket
          # Inform the client of connection
          basic_inform = "Hubeye running on #{Socket.gethostname} as #{@session.username}"
          if !@session.tracker.empty?
            @socket.puts "#{basic_inform}\nTracking:#{@session.tracker.keys.join ', '}"
          else
            @socket.puts basic_inform
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
    private :client_connect

    class Strategy
      UnknownStrategy = Class.new(StandardError)

      attr_accessor :server
      attr_accessor :input

      def initialize server
        self.server = server
        self.input = server.socket.gets
        unless @input
          Logger.log "Client on #{@server.socket.peeraddr[2]} disconnected."
          @server.sockets.delete(socket)
          @server.socket.close
          return
        end
        @input = @input.chop.strip.downcase
        @input.gsub! /diiv/, '/'
      end

      # strategy classes
      class Exit
        def start
          @socket.puts "Bye!"
          Logger.log "Closing connection to #{@socket.peeraddr[2]}"
          @server.remote_connection = false
          if !@session.tracker.empty?
            Logger.log "Tracking: #{@session.tracker.keys.join ', '}"
          end
          # to look pretty when multiple connections per loop
          Logger.log ""
          @sockets.delete(@socket)
          @socket.close
        end
      end

      class Shutdown
        def start
          Logger.log "Closing connection to #{@socket.peeraddr[2]}"
          Logger.log "Shutting down... (#{::Hubeye::Server::NOW})"
          Logger.log ""
          Logger.log ""
          @socket.puts("Shutting down server")
          @sockets.delete(@socket)
          @socket.close
          exit 0
        end
      end

      class SaveHook
        def start
          hooks = @session.hooks
          if !hooks.nil? and !hooks.empty?
            File.open("#{ENV['HOME']}/.hubeye/hooks/#{@matches[1]}.yml", "w") do |f_out|
              ::YAML.dump(hooks, f_out)
            end
            @socket.puts("Saved hook #{@matches[0]} as #{@matches[1]}")
          else
            @socket.puts("No hook #{@matches[0]} to save")
          end
        end
      end

      class SaveRepo
        def start
          if !@session.tracker.empty?
            File.open("#{ENV['HOME']}/.hubeye/repos/#{@matches[1]}.yml", "w") do |f_out|
              ::YAML.dump(@session.tracker, f_out)
            end
            @socket.puts("Saved repo #{@matches[0]} as #{@matches[1]}")
          else
            @socket.puts("No remote repos are being tracked")
          end
        end
      end

      class LoadHook
        def start
          hookfile = "#{ENV['HOME']}/.hubeye/hooks/#{@matches[1]}.yml"
          newhooks = nil
          if File.exists?(hookfile)
            File.open(hookfile) do |f|
              newhooks = ::YAML.load(f)
            end
            @hooks ||= {}
            @hooks = newhooks.merge(@session.hooks)
            @socket.puts("Loaded #{@matches[0]} #{@matches[1]}")
          else
            @socket.puts("No #{@matches[0]} file to load from")
          end
        end
      end

      class LoadRepo
        def start
          if File.exists?(repo_file = "#{ENV['HOME']}/.hubeye/repos/#{$matches[1]}.yml")
            newrepos = nil
            File.open(repo_file) do |f|
              newrepos = ::YAML.load(f)
            end
            if !newrepos
              @socket.puts "Unable to load #{@matches[1]}: empty file"
              return
            end
            # newrepos is an array of repos to be tracked
            newrepos.each do |e|
              # add the repo name and the commit hash to the hubeye tracker
              # array, then inform the client of the newest commit message
              username, repo = e.split '/'
              gh_user = User.find(username)
              gh_repo = gh_user.repository repo
              new_commit = gh_repo.commits.first
              @session.tracker.add_or_replace!(e, new_commit)
            end
            @socket.puts "Loaded #{$2}.\nTracking:\n#{@session.tracker.join ', '}"
          else
            @socket.puts("No file to load from")
          end
        end
      end

      class AddHook
        # @hooks:
        # repo is the key, value is array of directory and commands. First element
        # of array is the local directory for that remote repo, rest are commands
        # related to hooks called on change of commit message (with plans to change
        # that to commit SHA reference) of the remote repo
        def start
          if @matches[0] != nil && @matches[3] != nil
            if @session.hooks[@matches[0]]
              @session.hooks[@matches[0]] << @matches[3]
            elsif $matches[1] != nil
              @session.hooks[@matches[0]] = [ @matches[2], @matches[3] ]
            else
              @session.hooks[@matches[0]] = [@matches[3]]
            end
            @socket.puts("Hook added")
          else
            @socket.puts("Format: 'hook add user/repo [dir: /my/dir/repo ] cmd: git pull origin'")
          end
        end
      end

      class ListHooks
        def start
          unless @session.hooks.nil? || @session.hooks.empty?
            @session.hooks.each do |repo, ary|
              remote = repo
              if ary.first.include? '/'
                local = ary.first
                cmds  = ary[1..-1]
              else
                cmds = ary
                local = "N/A"
              end
              format_string = <<-EOS
  remote: #{remote}
    dir : #{local}
    cmds: #{cmds.each {|cmd| print cmd + ' ' }} \n
    EOS
            end
            @socket.puts(format_string)
          else
            @socket.puts("No hooks")
          end
        end
      end

      class ListTracking
        def start
          list = @session.tracker.keys.join ', '
          list = "none" if list.empty?
          @socket.puts(list)
        end
      end

      class Next
        def start
          @socket.puts("")
        end
      end

      class RmRepo
        def start
          if @matches[1].include?("/")
            @session.username, @session.repo_name = @matches[1].split('/')
          else
            @session.repo_name = @matches[1]
          end
          rm = @session.tracker.delete("#{@session.username}/#{@session.repo_name}")
          if rm
            @socket.puts("Stopped watching repository #{@session.username}/#{@session.repo_name}")
          else
            @socket.puts("Repository #{@session.username}/#{@session.repo_name} not currently being watched")
          end
        end
      end

      class AddRepo
        def start
          if @options and @options[:pwd]
            @session.repo_name = File.dirname(File.expand_path('.'))
          elsif @options and @options[:fullpath]
            @session.username, @session.repo_name = @input.split('/')
          else
            @session.repo_name = @input
          end
          add_repo
        end

        private
        def add_repo
          @full_repo_name = "#{@session.username}/#{@session.repo_name}"
          hist = nil
          # developer api v3
          begin
            open "https://api.github.com/repos/#{@session.username}/" \
            "#{@session.repo_name}/commits" do |f|
              hist = JSON.parse f.read
            end
          rescue
            @socket.puts "Not a Github repository name"
            return
          end
          new_sha = hist.first['sha']
          change = @session.tracker.add_or_replace!(@full_repo_name, new_sha)
          # get commit info
          first = hist.first
          commit_msg = first['commit']['message']
          committer  = first['commit']['committer']['name']
          url = first['url'][0..-30]
          msg = "#{commit_msg}\n=> #{committer}"
          # new repo to track
          if !change
            @socket.puts("Repository #{@full_repo_name} has not changed")
            return
          elsif change[:add]
            # log the fact that the user added a repo to be tracked
            Logger.log("Added to tracker: #{@full_repo_name} (#{::Hubeye::Server::NOW})")
            # show the user, via the client, the info and commit msg for the commit
            @socket.puts("#{msg}\n#{url}")
          elsif change[:replace]
            change_msg = "New commit on #{@full_repo_name}\n"
            change_msg << "#{msg}\n#{url}"
            @socket.puts(change_msg)
            begin
              if @daemonized
                Logger.log_change(@full_repo_name, commit_msg, committer)
              else
                Logger.log_change(@full_repo_name, commit_msg, committer,
                                  :include_terminal => true)
              end
            rescue
              return
            end
          end
        end
      end

      STRATEGY_CLASSES = [ Shutdown, Exit, SaveHook, SaveRepo,
        LoadHook, LoadRepo, AddHook, ListHooks, ListTracking,
        Next, RmRepo, AddRepo ]

      STRATEGIES = {
        %r{\Ashutdown\Z} => lambda {|m, s| Shutdown.new(m, s)},
        %r{\Aquit|exit\Z} => lambda {|m, s| Exit.new(m, s)},
        %r{\A\s*save hook(s?) as (.+)\Z} => lambda {|m, s| SaveHook.new(m, s)},
        %r{\A\s*save repo(s?) as (.+)\Z} => lambda {|m, s| SaveRepo.new(m, s)},
        %r{\A\s*load hook(s?) (.+)\Z} => lambda {|m, s| LoadHook.new(m, s)},
        %r{\A\s*load repo(s?) (.+)\Z} => lambda {|m, s| LoadRepo.new(m, s)},
        %r{hook add} => lambda {|m, s| AddHook.new(m, s)},
        %r{hook list} => lambda {|m, s| ListHooks.new(m, s)},
        %r{\Atracking\s*\Z} => lambda {|m, s| ListTracking.new(m, s)},
        %r{^pwd} => lambda {|m, s| AddRepo.new(m, s, :pwd => true)},
        %r{^\s*$} => lambda {|m, s| Next.new(m, s)},
        %r{\Arm ([\w-]+/?[\w-]*)\Z} => lambda {|m, s| RmRepo.new(m, s)},
        lambda {|inp| inp.include? '/'} => lambda {|m, s| AddRepo.new(m, s, :fullpath => true)},
        lambda {|inp| not inp.nil?} => lambda {|m, s| AddRepo.new(m, s)}
      }

      def call
        STRATEGIES.each do |inp,strat|
          if Regexp === inp
            if m = @input.match(inp)
              return strat.call(m, self)
            end
          elsif Proc === inp
            if m = inp.call(@input)
              return strat.call(m, self)
            end
          end
        end
        raise UnknownStrategy
      end


      STRATEGY_CLASSES.each do |klass|
        klass.class_eval do
          def initialize matches, strategy, options={}
            @options  = options unless options.empty?
            @matches  = matches
            @server   = strategy.server
            @socket   = @server.socket
            @sockets  = @server.sockets
            @session  = @server.session
            @input    = strategy.input
            start
          end
        end
      end

    end

  end # of Server module

  class HubeyeServer
    include Server

    def initialize(debug=true)
      @debug = debug
    end

  end
end

