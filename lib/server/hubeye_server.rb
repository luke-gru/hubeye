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

server = TCPServer.open(2000)       # Listen on port 2000
sockets = [server]            # An array of sockets we'll monitor
ary_commits_repos = []
hubeye_tracker = []
oncearound = 30
#USERNAME: defined in ~/.hubeyerc
USERNAME = 'luke-gru'
#find Desktop notification system
DESKTOP_NOTIFICATION = Notification::Finder.find_notify
#username: changes if input includes a '/' for removing, adding tracked repos
username = 'luke-gru'
@remote_connection = false


while true

  #if no client is connected, but the commits array contains repos
  if sockets.size == 1 and ary_commits_repos.empty? == false
    ary_commits_repos.each do |e|
      #put these repos in the array hubeye_tracker
      hubeye_tracker << e if ary_commits_repos.index(e).even?
      hubeye_tracker.uniq!
    end

    while @remote_connection == false
      hubeye_tracker.each do |repo|
        doc = Nokogiri::HTML(open("https://github.com/#{repo}/"))
        doc.xpath('//div[@class = "message"]/pre').each do |node|
          @commit_compare = node.text
          if ary_commits_repos.include?(@commit_compare)
            oncearound.times do
              sleep 1
              @remote_connection = client_connected(sockets) ? true : false
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

            ary_commits_repos << repo
            ary_commits_repos << @commit_compare
            #delete the repo and old commit that appear first in the array
            index_old_HEAD = ary_commits_repos.index(repo)
            ary_commits_repos.delete_at(index_old_HEAD)
            #and again to get rid of the commit message
            ary_commits_repos.delete_at(index_old_HEAD)
          end
        end
      end
      redo unless @remote_connection
    end
  end

  ready = select(sockets)

  def client_connected(sockets)
    select(sockets, nil, nil, 2)
  end

  readable = ready[0]           # These sockets are readable
  readable.each do |socket|         # Loop through readable sockets
    if socket == server         # If the server socket is ready
      client = server.accept    # Accept a new client
      sockets << client       # Add it to the set of sockets
      # Tell the client what and where it has connected.
      unless hubeye_tracker.empty?
        client.puts "Hubeye running on #{Socket.gethostname}\nTracking: #{hubeye_tracker.join(' ')}"
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
    else              # Otherwise, a client is ready
      input = socket.gets       # Read input from the client
      input.chop!           # Trim client's input

      # If no input, the client has disconnected
      if !input
        Logger.log "Client on #{socket.peeraddr[2]} disconnected."
        sockets.delete(socket)  # Stop monitoring this socket
        socket.close      # Close it
        next          # And go on to the next
      end

      if (input.strip.downcase == "quit")      # If the client asks to quit
        socket.puts("Bye!")   # Say goodbye
        Logger.log "Closing connection to #{socket.peeraddr[2]}"
        @remote_connection = false
        if !ary_commits_repos.empty?
          Logger.log "Tracking: "
          ary_commits_repos.each do |repo|
            Logger.log repo if ary_commits_repos.index(repo).even?
            hubeye_tracker.uniq!
          end
        end
        Logger.log "" # to look pretty when multiple connections per loop
        sockets.delete(socket)  # Stop monitoring the socket
        socket.close      # Terminate the session
        @still_logging = true

      elsif (input.strip.downcase == "shutdown")
        #local
        Logger.log "Closing connection to #{socket.peeraddr[2]}"
        Logger.log "Shutting down... (#{Time.now.strftime("%m/%d/%Y at %I:%M%p")})"
        Logger.log ""
        Logger.log ""
        #peer
        socket.puts("Shutting down server")
        sockets.delete(socket)
        socket.close
        exit
      else # Otherwise, client is not quitting

        #this means the user pressed '.' in the client, wanting to track the pwd
        if input.match(/^pwd/)
          repo_name = input[3..-1]
        elsif input.strip == ''
          socket.puts("")
          next
        elsif %r{rm ([\w-](diiv)?[\w-]*)} =~ input
          if $1.include?("diiv")
            username, repo_name = $1.split('diiv')
          else
            username, repo_name = "#{username}/#{$1}".split('/')
          end

          begin
            index_found = ary_commits_repos.index("#{username}/#{repo_name}")
            if index_found
              #consecutive indices in the array
              for i in 1..2
                ary_commits_repos.delete_at(index_found)
              end
              hubeye_tracker.delete("#{username}/#{repo_name}")
              socket.puts("Stopped watching repository #{username}/#{repo_name}")
              sleep 0.5
              next
            else
              socket.puts("Repository #{username}/#{repo_name} not currently being watched")
              next
            end
          rescue
            socket.puts($!)
            next
          end
        elsif input.include?('diiv')
          #includes a '/', such as rails/rails, but in the adding to tracker context
          username, repo_name = input.split('diiv')
        else
          #if the input is not the above special scenarios
          repo_name = input
        end

        begin
          #if adding a repo with another username
          doc = Nokogiri::HTML(open("https://github.com/#{username}/#{repo_name}"))
        rescue OpenURI::HTTPError
          socket.puts("Not a Github repository!")
          next
        rescue URI::InvalidURIError
          socket.puts("Not a valid URI")
          next
        end

        doc.xpath('//div[@class = "message"]/pre').each do |node|
          @commit_msg = node.text
        end

        doc.xpath('//div[@class = "actor"]/div[@class = "name"]').each do |node|
          @committer = node.text
        end

        if !ary_commits_repos.include?("#{username}/#{repo_name}".downcase.strip)
          ary_commits_repos << "#{username}/#{repo_name}"
          ary_commits_repos << @commit_msg

          doc.xpath('//div[@class = "machine"]').each do |node|
            @info =  node.text.strip!.gsub(/\n/, '').gsub(/tree/, "\ntree").gsub(/parent.*?(\w)/, "\nparent  \\1")
          end
          @msg =  "#{@commit_msg} => #{@committer}".gsub(/\(author\)/, '')
          #log the fact that the user added a repo to be tracked
          Logger.log("Added to tracker: #{ary_commits_repos[-2]} (#{Time.now.strftime("%m/%d/%Y at %I:%M%p")})")
          #show the user, via the client, the info and commit msg for the commit
          socket.puts("#{@info}\n#{@msg}")

        elsif !ary_commits_repos.include?(@commit_msg)
          begin
          index_of_msg = ary_commits_repos.index(username + "/" + repo_name) + 1
          ary_commits_repos.delete_at(index_of_msg)
          ary_commits_repos.insert(index_of_msg - 1, @commit_msg)

          #log to the logfile and tell the client
          Logger.log_change(repo_name, @commit_msg, @committer, socket)
          rescue
            socket.puts($!)
          end

        else
          socket.puts("Repository #{repo_name.downcase.strip} has not changed")
        end

      end
    end
  end
  username = USERNAME
  #reassign username to the username in ~/.hubeyerc
end

