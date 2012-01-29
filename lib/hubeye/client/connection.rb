require "hubeye/shared/hubeye_protocol"

module Hubeye
  module Client
    class Connection
      attr_reader :s, :local, :peer, :peeraddr

      def initialize(host, port)
        _begin do
          print "Connecting..."
          @s = TCPSocket.open(host, port)
          @s.sync = false
          @local, @peer = @s.addr, @s.peeraddr
          puts "Done" if @s
          puts "Connected to #{peer[2]}:#{peer[1]} using port #{local[1]}"
        end
      end

      def receive_welcome
        begin
          mesg = @s.read_all
          puts mesg
        rescue SystemCallError, NoMethodError
          puts "The server's not running!"
          exit 1
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

    end
  end
end
