module Hubeye
  module Server
    module Strategies

      class RmRepo
        def call
          if @options[:all]
            rm_all
            return
          end
          repo_name = @matches[1]
          full_repo_name = server.full_repo_name(repo_name)
          rm = tracker.delete(full_repo_name)
          if rm
            socket.deliver "Stopped watching repository #{full_repo_name}"
          else
            socket.deliver "Repository #{full_repo_name} not currently being watched"
          end
        end

        def rm_all
          if tracker.empty?
            socket.deliver "Not watching any repositories"
            return
          end
          repo_names = tracker.repo_names
          tracker.clear
          socket.deliver "Stopped watching repositories #{repo_names.join ', '}"
        end
      end # end of RmRepo

    end
  end
end
