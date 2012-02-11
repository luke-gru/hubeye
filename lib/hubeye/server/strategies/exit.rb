module Hubeye
  module Server
    module Strategies

      class Exit
        def call
          socket.deliver "Bye!"
          # mark the session as continuous to not wipe the log file
          session.continuous = true
          server.remote_connection = false
          Logger.log "Closing connection to #{socket.peeraddr[2]}"
          unless tracker.empty?
            Logger.log "Tracking: #{tracker.repo_names.join ', '}"
          end
          Logger.log ""
          sockets.delete(socket)
          socket.close
        end
      end

    end
  end
end
