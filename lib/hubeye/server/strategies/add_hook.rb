module Hubeye
  module Server
    module Strategies

      class AddHook
        def call
          cwd   = File.expand_path('.')
          repo  = @matches[1]
          _dir  = @matches[3]
          cmd   = @matches[4]
          hooks = session.hooks
          if repo.nil? and cmd.nil?
            socket.deliver "Format: 'hook add user/repo [dir: /my/dir/repo ] cmd: some_cmd'"
            return
          end
          if hooks[repo]
            _dir ? dir = _dir : dir = cwd
            if hooks[repo][dir]
              hooks[repo][dir] << cmd
            else
              hooks[repo][dir] = [cmd]
            end
          else
            dir = _dir || cwd
            hooks[repo] = {dir => [cmd]}
          end
          socket.deliver "Hook added"
        end
      end

    end
  end
end
