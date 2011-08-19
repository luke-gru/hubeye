module Server
  require 'socket'
  require 'open-uri'

  begin
    require 'nokogiri'
  rescue LoadError
    if require 'rubygems'
      retry
    else
      abort 'Nokogiri is needed to run hubeye. Gem install nokogiri'
    end
  end

  require "notification/notification"
  require "log/logger"

  ONCEAROUND = 30
  #USERNAME: defined in ~/.hubeyerc
  USERNAME = 'luke-gru'
  #find Desktop notification system
  DESKTOP_NOTIFICATION = Notification::Finder.find_notify

  class InputError < StandardError; end

  def start(port)
    listen(port)
    setup_env()
    _loop do
      catch(:next) do
      not_connected() unless @remote_connection
      get_input(@socket)
      puts @input
      parse_input()
      get_github_doc()
      parse_doc()
      @username = USERNAME
      end
    end
  end

  def listen(port)
    @server = TCPServer.open(port)       # Listen on port 2000
  end

  def setup_env
    @sockets = [@server]            # An array of sockets we'll monitor
    @ary_commits_repos = []
    @hubeye_tracker = []
    #username: changes if input includes a '/' for removing, adding tracked repos
    @username = 'luke-gru'
    @remote_connection = false
  end


  def _loop
    while true
      yield
    end
  end

  def not_connected
    #if no client is connected, but the commits array contains repos
    if @sockets.size == 1 and @ary_commits_repos.empty? == false
      @ary_commits_repos.each do |e|
        #put these repos in the array hubeye_tracker
        @hubeye_tracker << e if @ary_commits_repos.index(e).even?
        @hubeye_tracker.uniq!
      end

      while @remote_connection == false
        @hubeye_tracker.each do |repo|
          doc = Nokogiri::HTML(open("https://github.com/#{repo}/"))
          doc.xpath('//div[@class = "message"]/pre').each do |node|
            @commit_compare = node.text
            if @ary_commits_repos.include?(@commit_compare)
              ONCEAROUND.times do
                sleep 1
                @remote_connection = client_ready(@sockets) ? true : false
                break if @remote_connection
              end
            else
              #notify of change to repository
              #if they have libnotify installed
              doc.xpath('//div[@class = "actor"]/div[@class = "name"]').each do |node|
                @committer = node.text
              end

              if DESKTOP_NOTIFICATION == "libnotify"
                require "#{Environment::LIBDIR}/notification/gnomenotify"
                Autotest::GnomeNotify.notify("Hubeye", "Repo #{repo} has changed\nNew commit: #{@commit_compare} => #{@committer}", Autotest::GnomeNotify::CHANGE_ICON)
              else
                #TODO: check to see if the pid of the server is associated with a
                #terminal (or check the arguments for a -t). If found, log a
                #change to the repo to the terminal with the time in the same
                #format as the log page
              end
              @ary_commits_repos << repo
              @ary_commits_repos << @commit_compare
              #delete the repo and old commit that appear first in the array
              index_old_HEAD = @ary_commits_repos.index(repo)
              @ary_commits_repos.delete_at(index_old_HEAD)
              #and again to get rid of the commit message
              @ary_commits_repos.delete_at(index_old_HEAD)
            end
          end
        end
        redo unless @remote_connection
      end #end of (while remote_connection == false)
    end
    client_connect(@sockets)
  end

  def client_ready(sockets)
    select(sockets, nil, nil, 2)
  end
  private :client_ready

  def client_connect(sockets)
    ready = select(sockets)
    readable = ready[0]           # These sockets are readable
    readable.each do |socket|         # Loop through readable sockets
      if socket == @server         # If the server socket is ready
        client = @server.accept    # Accept a new client
        @socket = client
        sockets << client       # Add it to the set of sockets
        # Tell the client what and where it has connected.
        unless @hubeye_tracker.empty?
          client.puts "Hubeye running on #{Socket.gethostname}\nTracking: #{@hubeye_tracker.join(' ')}"
        else
          client.puts "Hubeye running on #{Socket.gethostname}"
          #TODO: if not daemonized, (by checking ps ax for hubeye start -t)
          #term = `ps ax | grep "hubeye start -t"`.scan(/.*\n/).first
          #term =~ /pts/
          puts "Client connected at #{Time.now.strftime("%m/%d/%Y at %I:%M%p")}"
        end
        client.flush
        # And log the fact that the client connected
        if @still_logging == true
          #if the client quit, do not wipe the log file
          Logger.log "Accepted connection from #{client.peeraddr[2]}"
        else
          #wipe the log file and start anew
          Logger.relog "Accepted connection from #{client.peeraddr[2]}"
        end
        Logger.log "local:  #{client.addr}"
        Logger.log "peer :  #{client.peeraddr}"
      end
    end
  end


  def get_input(socket)
    @input = socket.gets       # Read input from the client
    @input.chop!           # Trim client's input
    # If no input, the client has disconnected
    if !@input
      Logger.log "Client on #{socket.peeraddr[2]} disconnected."
      @sockets.delete(socket)  # Stop monitoring this socket
      socket.close      # Close it
      throw(:next)      # And go on to the next
    end
  end
  private :get_input

  def parse_input
    @input.strip!
    if quit = parse_quit()
    elsif shut = parse_shutdown()
    elsif pwd = parse_pwd()
    elsif empty = parse_empty()
    elsif remove = parse_remove()
    #hook must be before parse_fullpath_add
    elsif hook = parse_hook()
    elsif fullpath_add = parse_fullpath_add()
    elsif add = parse_add()
    else
      raise InputError "Invalid input #{@input}"
    end
  end

  def parse_quit
    if @input =~ /\Aquit|exit\Z/i      # If the client asks to quit
      @socket.puts("Bye!")   # Say goodbye
      Logger.log "Closing connection to #{@socket.peeraddr[2]}"
      @remote_connection = false
      if !@ary_commits_repos.empty?
        Logger.log "Tracking: "
        @ary_commits_repos.each do |repo|
          Logger.log repo if @ary_commits_repos.index(repo).even?
          @hubeye_tracker.uniq!
        end
      end
      Logger.log "" # to look pretty when multiple connections per loop
      @sockets.delete(@socket)  # Stop monitoring the socket
      @socket.close      # Terminate the session
      @still_logging = true
    else
      return
    end
    throw(:next)
  end

  def parse_shutdown
    if @input.downcase == "shutdown"
      #local
      Logger.log "Closing connection to #{@socket.peeraddr[2]}"
      Logger.log "Shutting down... (#{Time.now.strftime("%m/%d/%Y at %I:%M%p")})"
      Logger.log ""
      Logger.log ""
      #peer
      @socket.puts("Shutting down server")
    else
      return
    end
    shutdown()
  end


  def shutdown
    @sockets.delete(@socket)
    @socket.close
    exit
  end


  def parse_hook
    #if @input =~ /\Agithook add (\w+?(diiv)\w+) cmd: (.*)\Z/i
    if %r{githook} =~ @input
      @input.gsub!(/diiv/, '/')
      #make match globals parse input
      @input =~ /add ([^\/]+\/\w+) cmd: (.*)\Z/i
      require "hooks/git_hooks"
      @hook_cmds ||= {}
      #repo is the key, cmds are arrays of values (allowing same repo to have
      #numerous hooks methods)
      if $1 != nil || $2 != nil
        if @hook_cmds[$1]
          @hook_cmds[$1] << $2
        else
          @hook_cmds[$1] = [$2]
        end
        @socket.puts("Hook added")
      else
        @socket.puts("Format: 'githook add user/repo cmd: git pull origin'")
      end
    else
      return
    end
    p @hook_cmds
    throw(:next)
  end


  def parse_pwd
    #this means the user pressed '.' in the client,
    #wanting to track the pwd repo
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
    return true
  end

  def parse_remove
    if %r{\Arm ([\w-](diiv)?[\w-]*)\Z} =~ @input
      if $1.include?("diiv")
        @username, @repo_name = $1.split('diiv')
      else
        @username, @repo_name = "#{@username}/#{$1}".split('/')
      end

      begin
        index_found = @ary_commits_repos.index("#{@username}/#{@repo_name}")
        if index_found
          #consecutive indices in the array
          for i in 1..2
            @ary_commits_repos.delete_at(index_found)
          end
          @hubeye_tracker.delete("#{@username}/#{@repo_name}")
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
    return true
  end

  def parse_fullpath_add
    if @input.include?('diiv')
      #includes a '/', such as rails/rails, but in the adding to tracker context
      @username, @repo_name = @input.split('diiv')
    else
      return
    end
    return true
  end

  #if the input is not the above special scenarios
  def parse_add
    @repo_name = @input
  end

  def get_github_doc
    begin
      #if adding a repo with another username
      @doc = Nokogiri::HTML(open("https://github.com/#{@username}/#{@repo_name}"))
    rescue OpenURI::HTTPError
      @socket.puts("Not a Github repository!")
      throw(:next)
    rescue URI::InvalidURIError
      @socket.puts("Not a valid URI")
      throw(:next)
    end
  end

  def parse_doc
    #get commit msg
    @commit_msg = parse_msg()
    #get committer
    @committer = parse_committer()

    #new repo to track
    if !@ary_commits_repos.include?("#{@username}/#{@repo_name}".downcase.strip)
      @ary_commits_repos << "#{@username}/#{@repo_name}"
      @ary_commits_repos << @commit_msg
      #get commit info
      @info = parse_info()
      @msg =  "#{@commit_msg} => #{@committer}".gsub(/\(author\)/, '')
      #log the fact that the user added a repo to be tracked
      Logger.log("Added to tracker: #{@ary_commits_repos[-2]} (#{Time.now.strftime("%m/%d/%Y at %I:%M%p")})")
      #show the user, via the client, the info and commit msg for the commit
      @socket.puts("#{@info}\n#{@msg}")

    #new commit to tracked repo
    elsif !@ary_commits_repos.include?(@commit_msg)
      begin
        index_of_msg = @ary_commits_repos.index(@username + "/" + @repo_name) + 1
        @ary_commits_repos.delete_at(index_of_msg)
        @ary_commits_repos.insert(index_of_msg - 1, @commit_msg)

        #log to the logfile and tell the client
        Logger.log_change(@repo_name, @commit_msg, @committer, @socket)
      rescue
        @socket.puts($!)
      end

    else
      #no change
      @socket.puts("Repository #{@repo_name.downcase.strip} has not changed")
    end
  end

  def parse_msg
    #get commit msg
    @doc.xpath('//div[@class = "message"]/pre').each do |node|
      return commit_msg = node.text
    end
  end

  def parse_committer
    @doc.xpath('//div[@class = "actor"]/div[@class = "name"]').each do |node|
      return committer = node.text
    end
  end

  def parse_info
    @doc.xpath('//div[@class = "machine"]').each do |node|
      return info =  node.text.strip!.gsub(/\n/, '').gsub(/tree/, "\ntree").gsub(/parent.*?(\w)/, "\nparent  \\1")
    end
  end

end #of of Server module

class Hubeye_Server
  include Server
end

server = Hubeye_Server.new
server.start(2000)

