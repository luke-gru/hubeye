module Hubeye
  module Server
    module Strategies

      class AddHook
        def call
          cwd       = File.expand_path('.')
          repo_name = @matches[1]
          directory = @matches[3]
          command   = @matches[4]
          hooks     = session.hooks
          if repo_name.nil? and command.nil?
            socket.deliver "Format: 'hook add user/repo [dir: /my/dir/repo ] cmd: some_cmd'"
            return
          end
          directory = directory || cwd
          if hooks[repo_name]
            if hooks[repo_name][directory]
              hooks[repo_name][directory] << command
            else
              hooks[repo_name][directory] = [command]
            end
          else
            hooks[repo_name] = {directory => [command]}
          end
          socket.deliver "Hook added"
        end
      end

    end
  end
end
