module Hubeye
  module Server

    # simple interface to Github's api v3 for commits
    class Commit
      attr_reader :repo_name, :sha, :message, :committer_name

      def initialize(repo_name, raw_commit_ary)
        commit_hash = parse_raw_commit_ary(raw_commit_ary)
        @repo_name = repo_name
        @sha = commit_hash['sha']
        @message = commit_hash['commit']['message']
        @committer_name = commit_hash['commit']['committer']['name']
      end

      private
      def parse_raw_commit_ary(raw_commit_ary)
        {'sha' => raw_commit_ary.first['sha'],
         'commit' =>
           {'message' => raw_commit_ary.first['commit']['message'],
            'committer' =>
              {'name' => raw_commit_ary.first['commit']['committer']['name']}
           }
        }
      end

    end
  end
end

