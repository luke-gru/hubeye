module Hooks
  module Git

    module Default

      def self.fetch(local_reponame, remotename, branchname)
        Dir.chdir(File.expand_path(local_reponame)) do
          ::Kernel.system("git fetch #{remotename} #{branchname}")
        end
      end

      def self.pull(local_reponame, remotename, branchname)
        Dir.chdir(File.expand_path(local_reponame)) do
          ::Kernel.system("git pull #{remotename} #{branchname}")
        end
      end

    end

  end
end
