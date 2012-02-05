require 'forwardable'
require 'json'
require File.expand_path('../commit', __FILE__)

module Hubeye
  module Server
    class Tracker
      extend Forwardable
      def_delegators :@server, :socket, :session
      def_delegators :@commit_list, :[], :last, :first, :length, :each, :empty?
      attr_reader :commit_list

      def initialize(server)
        @server = server
        @commit_list = []
      end

      # Returns {:added     => true},
      #         {:replaced  => true}, OR
      #         {:unchanged => true}
      # A commit won't be added if the repo is already tracked
      # and the newly searched for commit sha is the same as the
      # old one. Every call to #add requires a trip to a Github
      # server.
      def add(repo)
        repo_name = full_repo_name(repo)
        raw_commit_ary = recent_repo_info(repo_name)
        commit = Commit.new(repo_name, raw_commit_ary)
        if tracked?(repo_name) && unchanged?(commit)
          return {:unchanged => true}
        end
        ret = tracked?(repo_name) ? {:replaced => true} : {:added => true}
        # update the list
        @commit_list.reject! {|cmt| cmt.repo_name == repo_name}
        @commit_list << commit
        ret
      end

      alias << add

      # Returns true if changed, false otherwise.
      def delete(repo_name)
        repo_name = full_repo_name(repo)
        old = @commit_list.dup
        @commit_list.delete_if {|cmt| cmt.repo_name == repo_name}
        old == @commit_list ? false : true
      end

      def commit(repo)
        @commit_list.each {|cmt| return cmt if cmt.repo_name == full_repo_name(repo)}
        nil
      end

      def repo_names
        commit_list.map(&:repo_name)
      end

      private
      def tracked?(full_repo_name)
        repo_names.include? full_repo_name
      end

      # unchanged: after this new commit's sha is found to be in the
      # commit_list
      def unchanged?(new_commit_obj)
        @commit_list.each {|cmt| return true if cmt.sha == new_commit_obj.sha}
        false
      end

      def recent_repo_info(full_repo_name)
        username, repo_name = full_repo_name.split '/'
        info = nil
        begin
          open "https://api.github.com/repos/#{username}/" \
          "#{repo_name}/commits" do |f|
            info = JSON.parse f.read
          end
        rescue => e
          unless Hubeye.test?
            socket.deliver "Not a Github repository name"
            throw(:invalid_input)
          end
        end
        info
      end

      def full_repo_name(repo)
        if repo.include? '/'
          repo
        else
          "#{session.username}/#{repo}"
        end
      end

    end
  end
end
