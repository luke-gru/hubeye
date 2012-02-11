module Hubeye
  module Server
    module Strategies

      class Shutdown
        def call
          Logger.log "Closing connection to #{socket.peeraddr[2]}"
          Logger.log "Shutting down... (#{NOW})"
          Logger.log ""
          Logger.log ""
          socket.deliver "Shutting down server"
          sockets.delete(socket)
          socket.close
          unless server.daemonized
            STDOUT.puts "Shutting down gracefully."
          end
          exit 0
        end
      end

    end
  end
end
