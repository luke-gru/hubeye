require 'yaml'

module Hubeye
  module Server
    module Strategies

      class LoadRepo
        def call
          if _t = @options[:internal]
            @silent = _t
          end
          if File.exists?(repo_file = "#{ENV['HOME']}/.hubeye/repos/#{@matches[2]}.yml")
            new_repos = nil
            File.open(repo_file) do |f|
              new_repos = YAML.load(f)
            end
            if !new_repos
              socket.deliver "Unable to load #{@matches[2]}: empty file" unless @silent
              return
            end
            new_repos.each do |r|
              tracker << server.full_repo_name(r)
            end
            unless @silent
              socket.deliver "Loaded #{@matches[2]}.\nTracking:\n#{tracker.repo_names.join ', '}"
            end
          else
            socket.deliver "No file to load from"  unless @silent
          end
        end
      end

    end
  end
end
