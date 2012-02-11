require 'yaml'

module Hubeye
  module Server
    module Strategies

      class SaveHook
        def call
          hooks = session.hooks
          if !hooks.empty?
            file = "#{ENV['HOME']}/.hubeye/hooks/#{@matches[2]}.yml"
            if File.exists? file
              override?
            end
            File.open(file, "w") do |f_out|
              YAML.dump(hooks, f_out)
            end
            socket.deliver "Saved hook#{@matches[1]} as #{@matches[2]}"
          else
            socket.deliver "No hook#{@matches[1]} to save"
          end
        end

        private
        def override?
        end
      end

    end
  end
end
