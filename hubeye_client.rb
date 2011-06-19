#!/usr/bin/env ruby
require 'socket'

host = 'localhost'
port = 2000
begin
  # Give the user some feedback while connecting.
  STDOUT.print "Connecting..."      # Say what we're doing
  STDOUT.flush            # Make it visible right away
  s = TCPSocket.open(host, port)    # Connect
  STDOUT.puts "done"          # And say we did it
  # Now display information about the connection.
  local, peer = s.addr, s.peeraddr

  STDOUT.print "Connected to #{peer[2]}:#{peer[1]}"
  STDOUT.puts " using local port #{local[1]}"
  # Wait just a bit, to see if the server sends any initial message.
  begin
    sleep(0.5)            # Wait half a second
    msg = s.read_nonblock(4096)     # Read whatever is ready
    STDOUT.puts msg.chop      # And display it
  rescue SystemCallError
    # If nothing was ready to read, just ignore the exception.
  end
  # Now begin a loop of client/server interaction.
  while s
    loop do
      STDOUT.print '> '           # Display prompt for local input
      STDOUT.flush          # Make sure the prompt is visible
      local = STDIN.gets        # Read line from the console
      #break if !local             # Quit if no input from console
      s.puts(local)             # Send the line to the server
      s.flush               # Force it out
      # Read the server's response and print out.
      # The server may send more than one line, so use readpartial
      # to read whatever it sends (as long as it all arrives in one chunk).
      sleep(0.5)
      response = s.readpartial(4096)
      if response.chop.strip == "Bye!"
        puts(response.chop)
        s.close
        exit
      elsif response.chop.strip.match(/shutting/i)
        s.close
        exit
      else
        puts(response.chop)         # Display response to user
        next
      end

    end
  end
rescue                  # If anything goes wrong
  puts $!                 # Display the exception to the user
end
puts "Connection closed"
