require 'yaml'

module Hubeye
  module Server
    module Strategies

      class LoadHook
        def call
          if _t = @options[:internal]
            @silent = _t
          end
          hookfile = "#{ENV['HOME']}/.hubeye/hooks/#{@matches[2]}.yml"
          new_hooks = nil
          if File.exists?(hookfile)
            File.open(hookfile) do |f|
              new_hooks = YAML.load(f)
            end
            # need to fix this to check if there are already commands for that
            # repo
            session.hooks.merge!(new_hooks)
            unless @silent
              socket.deliver "Loaded #{@matches[1]} #{@matches[2]}"
            end
          else
            unless @silent
              socket.deliver "No #{@matches[1]} file to load from"
            end
          end
        end
      end

    end
  end
end
