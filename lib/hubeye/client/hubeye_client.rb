#!/usr/bin/env ruby
require 'socket'

module Hubeye
  class Connection
    attr_reader :s, :local, :peer, :peeraddr

    def initialize(host, port)
      _begin do
        # Give the user some feedback while connecting.
        STDOUT.print "Connecting..."
        STDOUT.flush
        @s = TCPSocket.open(host, port)
        STDOUT.puts "Done" if @s

        # Now display information about the connection.
        @local, @peer = @s.addr, @s.peeraddr

        STDOUT.print "Connected to #{peer[2]}:#{peer[1]}"
        STDOUT.puts " using local port #{local[1]}"
      end
    end

    def receive_welcome
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

    private

    def _begin
      begin
        yield
      rescue
        @debug ? puts($!) : nil
      end
    end
  end # end class Connection

  class HubeyeClient

    def start(host, port, debug=false)
      @debug = debug
      conn = Connection.new(host, port)
      conn.receive_welcome
      interact(conn.s)
    end

    # Now begin a loop of client/server interaction.
    def interact(socket)
      @s = socket
      while @s
        loop do
          STDOUT.print '> '
          STDOUT.flush
          local = STDIN.gets
          begin
            if local.match(/^\.$/) # '.' = pwd (of client process)
              @s.puts local.gsub(/\A\.\Z/, File.split(File.expand_path('.')).last)
            else
              @s.puts local.gsub(/\//, 'diiv')
            end
          rescue
            # Errno::EPIPE for broken pipes in Unix (server got an ^C or
            # something like that)
            exit 1
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
            response = "Bye!\n"
          end
          if response.chop.strip == "Bye!"
            response[-1] == "\n" ? print(response) : puts(response)
            @s.close
            exit 0
          elsif response.chop.strip.match(/shutting/i)
            @s.close
            exit 0
          else
            response[-1] == "\n" ? print(response) : puts(response)
            next
          end
        end
      end
    end
  end # end HubeyeClient
end # end Hubeye

