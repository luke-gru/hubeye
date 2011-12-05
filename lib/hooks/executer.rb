module Hooks
  class Command

    class NoHookError < ArgumentError; end

      #options include the directory to execute the command
      #(that's it for now, will add more functionality later)
      def self.execute(commands, options={})
        opts = {:directory => nil, :repo => nil}.merge(options)
        dir  = opts[:directory]
        repo = opts[:repo]
        begin
          commands.each do |cmd|
            if dir
              Dir.chdir(File.expand_path(dir)) do
                ::Kernel.system cmd
              end
            else
              ::Kernel.system cmd
            end
          end
        rescue ArgumentError
          raise NoHookError.new "There aren't any hook commands for the repository #{repo}"
        end
      end

  end
end

