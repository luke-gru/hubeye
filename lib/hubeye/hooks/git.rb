module Hubeye
  module Hooks
    class Git

      def self.fetch(local_repo_name, remote_name, branch_name)
        Dir.chdir(File.expand_path(local_repo_name)) do
          system "git fetch #{remote_name} #{branch_name}"
        end
      end

      def self.pull(local_repo_name, remote_name, branch_name)
        Dir.chdir(File.expand_path(local_repo_name)) do
          system "git pull #{remote_name} #{branch_name}"
        end
      end

    end
  end
end
