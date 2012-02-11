require 'yaml'

module Hubeye
  module Server
    module Strategies

      class SaveRepo
        def call
          if !tracker.empty?
            file = "#{ENV['HOME']}/.hubeye/repos/#{@matches[2]}.yml"
            if File.exists? file
              override?
            end
            # dump only the repository names, not the shas
            File.open(file, "w") do |f_out|
              YAML.dump(tracker.repo_names, f_out)
            end
            socket.deliver "Saved repo#{@matches[1]} as #{@matches[2]}"
          else
            socket.deliver "No remote repos are being tracked"
          end
        end

        private
        def override?
        end
      end

    end
  end
end
