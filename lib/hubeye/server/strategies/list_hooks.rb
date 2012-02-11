module Hubeye
  module Server
    module Strategies

      class ListHooks
        def call
          hooks = session.hooks
          if hooks.empty?
            socket.deliver "No hooks"
            return
          end
          pwd = File.expand_path('.')
          format_string = ""
          hooks.each do |repo, hash|
            local_dir = nil
            command = nil
            hash.each do |dir,cmd|
              if dir.nil?
                local_dir = pwd
                command = cmd.join("\n" + (' ' * 8))
              else
                command = cmd
                local_dir = dir
              end
            end
            format_string << <<EOS
remote: #{repo}
dir:    #{local_dir}
cmds:   #{command}\n
EOS
          end
          socket.deliver format_string
        end
      end

    end
  end
end
