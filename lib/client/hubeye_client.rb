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
      STDOUT.flush
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
      sleep 1
      msg = @s.readpartial(4096)
      STDOUT.puts msg.chop
    rescue SystemCallError, NoMethodError
      STDOUT.puts "The server's not running!"
    rescue EOFError
      @retried ||= -1
      @retried += 1
      retry unless @retried >= 1
    end
  end

  # Now begin a loop of client/server interaction.
  def interact
    while @s
      loop do
        STDOUT.print '> '
        STDOUT.flush
        local = STDIN.gets
        if local.match(/^\.$/) # '.' = pwd
          # Send the line to the server, daemons gem strips some special chars (/, :)
          @s.puts(local.gsub(/\A\.\Z/, "pwd" + Dir.pwd.split('/').last))
        else
          @s.puts(local.gsub(/\//, 'diiv'))
        end
        @s.flush
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

