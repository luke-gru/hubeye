module Hooks
  class Command

    class NoCommandError < ArgumentError; end

      #options include the directory to execute the command
      #(that's it for now, will add more functionality later)
      def self.execute(commands=[], options={})
        opts = {:directory => nil, :repo => nil}.merge(options)
        dir  = opts[:dir]
        repo = opts[:repo]
        begin

        commands.each do |com|
          Dir.chdir(File.expand_path(dir)) do
            ::Kernel.system com
          end
        end

        rescue ArgumentError
          raise NoCommandError.new "There aren't any commands for the repository #{repo}"
        end
      end

  end
end
