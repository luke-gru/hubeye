#!/usr/bin/env ruby
require 'socket'
server = TCPServer.open(2000)       # Listen on port 2000
sockets = [server]            # An array of sockets we'll monitor
log = STDOUT              # Send log messages to standard out
ary_commits_repos = []
while true                # Servers loop forever
  ready = select(sockets)         # Wait for a socket to be ready
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

        require 'open-uri'
        require 'nokogiri'


        if input == '' or input == '.'
          repo_name = File.expand_path(".").split("/").last
        else
          repo_name = input
        end

        begin
          doc = Nokogiri::HTML(open("https://github.com/luke-gru/#{repo_name}"))
        rescue OpenURI::HTTPError
          socket.puts("Not a git repository!")
          next
        rescue URI::InvalidURIError
          socket.puts("Bad URI")
          next
        end


        doc.xpath('//div[@class = "message"]/pre').each do |node|
          @commit_msg = node.text
        end

        doc.xpath('//div[@class = "actor"]/div[@class = "name"]').each do |node|
          @committer = node.text
        end

        if !ary_commits_repos.include?(input.downcase)
          ary_commits_repos << input
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
          socket.puts("Repository: #{input.downcase} has changed")
          socket.puts("Commit msg: #{@commit_msg}") 
          socket.puts(" Committer: #{@committer}")
          socket.puts("===============================")
        else
          socket.puts("Repository #{input.downcase} has not changed")
        end

      end
    end
  end
end

