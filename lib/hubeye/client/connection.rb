module Hubeye
  module Client
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
        @s.sync = false
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
  end # end of module Client
end # end of module Hubeye

