module Hooks
  module Git

    module Default

      def self.fetch(local_reponame, remotename, branchname)
        #first, start a process to cd to the local repo
        #then fetch the remote
        Dir.chdir(File.expand_path(local_reponame)) do
          ::Kernel.system("git fetch #{remotename} #{branchname}")
        end
      end

      def self.pull(local_reponame, remotename, branchname)
        #first, start a process to cd to the local repo
        #then pull the remote
        Dir.chdir(File.expand_path(local_reponame)) do
          ::Kernel.system("git pull #{remotename} #{branchname}")
        end
      end

    end

  end
end
