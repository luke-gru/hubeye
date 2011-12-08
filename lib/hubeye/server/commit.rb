module Hubeye
  module Server

  # simple interface to Github's api v3 for commits
    class Commit
      attr_reader :raw_input, :repo, :only_sha, :latest

      def initialize(input)
        @raw_input = input
        @repo = input.keys.first
        if Hash === input
          if input[@repo].keys == ["sha"]
            @only_sha = true
          else
            @latest = true
          end
        else
          raise ArgumentError.new "input must be a kind of hash"
        end
      end

      def sha
        @sha ||= @raw_input[@repo]['sha']
      end

      def commit_message
        if @only_sha
          return
        elsif @latest
          @commit_message ||=
            @raw_input[@repo]['commit']['message']
        else
          raise
        end
      end

      def committer_name
        if @only_sha
          return
        elsif @latest
          @committer_name ||=
            @raw_input[@repo]['commit']['committer']['name']
        else
          raise
        end
      end

    end
  end
end

