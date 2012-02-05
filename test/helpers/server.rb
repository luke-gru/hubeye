module Test
  module Helpers
    module Server

      class << $stdout
        alias deliver puts
        def close; end
        def read_all
          gets.chomp
        end
        def peeraddr
          ['', '', '']
        end
        def addr
          ''
        end
      end

      def _test_client_connect(io_ary)
        @socket = $stdin
        # Inform the client of connection
        basic_inform = "Hubeye running on #{Socket.gethostname} as #{@session.username}"
        if !@session.tracker.empty?
          @socket.deliver "#{basic_inform}\nTracking: #{@session.tracker.keys.join ', '}"
        else
          @socket.deliver basic_inform
        end
        puts "Client connected at #{NOW}" unless @daemonized
        if @session.continuous
          Logger.log "Accepted connection from STDIN (#{NOW})"
        else
          # wipe the log file and start fresh
          Logger.relog "Accepted connection from STDIN (#{NOW})"
        end
      end

    end
  end
end
