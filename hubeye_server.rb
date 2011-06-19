#!/usr/bin/env ruby
require 'socket'
require 'open-uri'
require 'nokogiri'

server = TCPServer.open(2000)       # Listen on port 2000
sockets = [server]            # An array of sockets we'll monitor
log = STDOUT              # Send log messages to standard out
ary_commits_repos = []
hubeye_tracker = []
oncearound = 10
username = "luke-gru"
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
            puts repo + " hasn't changed"
            oncearound.times do
              sleep 1
              @remote_connection = client_connected(sockets) ? true : false
              break if @remote_connection
            end
          else
            puts repo + " has changed"
            print "new commit msg: #{@commit_compare}"
            doc.xpath('//div[@class = "actor"]/div[@class = "name"]').each do |node|
              @committer = node.text
            end
            print " => #{@committer}\n"
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
  p sockets

  def client_connected(sockets)
    select(sockets, nil, nil, 5)
  end

  readable = ready[0]           # These sockets are readable
  readable.each do |socket|         # Loop through readable sockets
    if socket == server         # If the server socket is ready
      client = server.accept    # Accept a new client
      sockets << client       # Add it to the set of sockets
      # Tell the client what and where it has connected.
      client.puts "Hubeye running on #{Socket.gethostname}"
      # And log the fact that the client connected
      log.puts "Accepted connection from #{client.peeraddr[2]}"
      log.puts "local:  #{client.addr}"
      log.puts "peer :  #{client.peeraddr}"
    else              # Otherwise, a client is ready
      input = socket.gets       # Read input from the client
      input.chop!           # Trim client's input

      # If no input, the client has disconnected
      if !input
        log.puts "Client on #{socket.peeraddr[2]} disconnected."
        sockets.delete(socket)  # Stop monitoring this socket
        socket.close      # Close it
        next          # And go on to the next
      end


      if (input.strip.downcase == "quit")      # If the client asks to quit
        socket.puts("Bye!");    # Say goodbye
        log.puts "Closing connection to #{socket.peeraddr[2]}"
        if !ary_commits_repos.empty?
          print "Tracking: "
          ary_commits_repos.each do |repo|
            print repo + " " if ary_commits_repos.index(repo).even?
            hubeye_tracker.uniq!
          end
          log.puts
        end
        log.puts #to look pretty when multiple connections per loop
        sockets.delete(socket)  # Stop monitoring the socket
        socket.close      # Terminate the session
      elsif (input.strip.downcase == "shutdown")
        #local
        log.puts "Closing connection to #{socket.peeraddr[2]}"
        log.puts "Shutting down..."
        #peer
        socket.puts("Shutting down server")
        sockets.delete(socket)
        socket.close
        exit
      else # Otherwise, client is not quitting



        if input == '.'
          repo_name = File.expand_path(".").split("/").last
        elsif input.include?("/")
          username, repo_name = input.split("/")
        elsif input.strip == ''
          socket.puts("")
          next
        else
          repo_name = input
        end

        begin
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
          log.puts("#{ary_commits_repos.inspect}")
          socket.puts("#{@info}\n#{@msg}")

        elsif !ary_commits_repos.include?(@commit_msg)
          index_of_msg = ary_commits_repos.index(input) + 1
          ary_commits_repos.delete_at(index_of_msg)
          ary_commits_repos.insert(index_of_msg - 1, @commit_msg)
          socket.puts("===============================")
          socket.puts("Repository: #{repo_name.downcase.strip} has changed")
          socket.puts("Commit msg: #{@commit_msg}") 
          socket.puts(" Committer: #{@committer}")
          socket.puts("===============================")
        else
          socket.puts("Repository #{repo_name.downcase.strip} has not changed")
        end

      end
    end
  end
end

