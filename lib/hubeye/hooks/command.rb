module Hubeye
  module Hooks
    class Command

      class NoHookError < ArgumentError; end

      # options include the directory to execute the command and
      # the full repo name of the changed repository
      def self.execute(commands, options={})
        opts = {:directory => nil, :repo => nil}.merge(options)
        dir  = opts[:directory]
        repo = opts[:repo]
        begin
          commands.each do |cmd|
            if dir
              Dir.chdir(File.expand_path(dir)) do
                if repo
                  ::Kernel.system "HUBEYE_CHANGED_REPO=#{repo} #{cmd}"
                else
                  ::Kernel.system cmd
                end
              end
            else
              ::Kernel.system cmd
            end
          end
        rescue ArgumentError
          raise NoHookError, "There aren't any hook commands for the repository #{repo}"
        end
      end

    end
  end
end
