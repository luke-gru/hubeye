#!/usr/bin/env ruby
require 'socket'

class HubeyeClient

  def start(host, port)
    connect(host, port)
    read_welcome()
    interact()
  end

  def _begin
    begin
      yield
    rescue
      puts $!                 # Display the exception to the user
    end
  end

  def connect(host, port)
    _begin do
      # Give the user some feedback while connecting.
      STDOUT.print "Connecting..."      # Say what we're doing
      STDOUT.flush            # Make it visible right away
      @s = TCPSocket.open(host, port)    # Connect
      STDOUT.puts "Done" if @s

      # Now display information about the connection.
      local, peer = @s.addr, @s.peeraddr

      STDOUT.print "Connected to #{peer[2]}:#{peer[1]}"
      STDOUT.puts " using local port #{local[1]}"
    end
  end

  def read_welcome
    # Wait just a bit, to see if the server sends any initial message.
    begin
      sleep(0.5)            # Wait half a second
      msg = @s.readpartial(4096)     # Read whatever is ready
      STDOUT.puts msg.chop      # And display it
    rescue SystemCallError
      # If nothing was ready to read, just ignore the exception.
    rescue NoMethodError
      STDOUT.puts "The server's not running!"
    end
  end

    # Now begin a loop of client/server interaction.
  def interact
    while @s
      loop do
        STDOUT.print '> '           # Display prompt for local input
        STDOUT.flush          # Make sure the prompt is visible
        local = STDIN.gets        # Read line from the console
        #break if !local             # Quit if no input from console
        if local.match(/^\.$/) #pwd
          @s.puts(local.gsub(/\A\.\Z/, "pwd" + Dir.pwd.split('/').last))    # Send the line to the server, daemons gem strips some special chars (/, :)
        else
          @s.puts(local.gsub(/\//, 'diiv'))
        end
        @s.flush               # Force it out
        # Read the server's response and print out.
        # The server may send more than one line, so use readpartial
        # to read whatever it sends (as long as it all arrives in one chunk).
        sleep(0.5)
        response = @s.readpartial(4096)
        if response.chop.strip == "Bye!"
          puts(response.chop)
          @s.close
          exit
        elsif response.chop.strip.match(/shutting/i)
          @s.close
          exit
        else
          puts(response.chop)         # Display response to user
          next
        end
      end
    end
  end

end #end of class

