#!/usr/bin/env ruby
require 'socket'

class HubeyeClient

  def start(host, port, debug=false)
    @debug = debug
    connect(host, port)
    read_welcome
    interact
  end

  def _begin
    begin
      yield
    rescue
      puts $! if @debug
    end
  end

  def connect(host, port)
    _begin do
      # Give the user some feedback while connecting.
      STDOUT.print "Connecting..."
      STDOUT.flush # Make it visible right away
      @s = TCPSocket.open(host, port) # Connect
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
      sleep 1 # Wait a second
      msg = @s.readpartial(4096) # Read whatever is ready
      STDOUT.puts msg.chop # And display it
    rescue SystemCallError, NoMethodError
      STDOUT.puts "The server's not running!"
    end
  end

    # Now begin a loop of client/server interaction.
  def interact
    while @s
      loop do
        STDOUT.print '> '
        STDOUT.flush # Make sure the prompt is visible
        local = STDIN.gets
        if local.match(/^\.$/) # '.' = pwd
          @s.puts(local.gsub(/\A\.\Z/, "pwd" + Dir.pwd.split('/').last))    # Send the line to the server, daemons gem strips some special chars (/, :)
        else
          @s.puts(local.gsub(/\//, 'diiv'))
        end
        @s.flush # Force it out

        # Read the server's response and print out.
        # The server may send more than one line, so use readpartial
        # to read whatever it sends (as long as it all arrives in one chunk).
        if local =~ /load repo/
          puts "Loading..."
          sleep 1
        else
          sleep 0.5
        end

        begin
          response = @s.readpartial(4096)
        rescue EOFError
          response = "Bye!"
        end

        if response.chop.strip == "Bye!"
          puts response.chop
          @s.close
          exit 0
        elsif response.chop.strip.match(/shutting/i)
          @s.close
          exit 0
        else
          puts response.chop
          next
        end
      end
    end
  end

end

