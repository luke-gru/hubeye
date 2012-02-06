require File.expand_path('../commit', __FILE__)
require File.expand_path('../session', __FILE__)
require 'forwardable'
require 'json'
require 'open-uri'

module Hubeye
  module Server
    class Tracker
      extend Forwardable
      def_delegators :@commit_list, :[], :last, :first, :length, :each, :empty?, :clear
      attr_reader :commit_list

      def initialize
        @commit_list = []
      end

      # Returns {:added     => true},
      #         {:replaced  => true},
      #         {:unchanged => true}, OR
      #         {:invalid   => true}
      # A commit won't be added if the repo is already tracked
      # and the newly searched for commit sha is the same as the
      # old one. Every call to #add requires a trip to a Github
      # server.
      # NOTE: takes full repo_name only
      def add(repo_name)
        raw_commit_ary = recent_repo_info(repo_name)
        return {:invalid => true} unless raw_commit_ary
        commit = Commit.new(repo_name, raw_commit_ary)
        if tracked?(repo_name) && unchanged?(commit)
          return {:unchanged => true}
        end
        ret = tracked?(repo_name) ? {:replaced => true} : {:added => true}
        # update the list
        @commit_list.reject! {|cmt| cmt.repo_name == repo_name} if ret[:replaced]
        @commit_list << commit
        ret
      end

      alias << add

      # Returns true if changed, false otherwise.
      # NOTE: takes repo name only
      def delete(repo_name)
        old = @commit_list.dup
        @commit_list.delete_if {|cmt| cmt.repo_name == repo_name}
        old == @commit_list ? false : true
      end

      def commit(repo)
        @commit_list.each {|cmt| return cmt if cmt.repo_name == full_repo_name(repo)}
        nil
      end
      alias tracking? commit

      def repo_names
        @commit_list.map {|cmt| cmt.repo_name }
      end

      private
      def tracked?(full_repo_name)
        repo_names.include? full_repo_name
      end

      # unchanged: after this new commit's sha is found to be in the commit_list
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
          return
        end
        info
      end

    end
  end
end
