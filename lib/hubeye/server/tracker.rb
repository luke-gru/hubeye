require File.expand_path('../commit', __FILE__)
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

      # returns {:added     => true},
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
        if tracking?(repo_name) && unchanged?(commit)
          return {:unchanged => true}
        end
        ret = tracking?(repo_name) ? {:replaced => true} : {:added => true}
        # update the list
        @commit_list.reject! {|cmt| cmt.repo_name == repo_name} if ret[:replaced]
        @commit_list << commit
        ret
      end

      alias << add

      # returns true if deleted, false otherwise.
      def delete(repo_name)
        old_length = @commit_list.length
        @commit_list.delete_if {|cmt| cmt.repo_name == repo_name}
        new_length = @commit_list.length
        old_length != new_length
      end

      # returns the most recently tracked commit object for that full repo
      # name, or nil if it isn't tracked.
      def commit(repo_name)
        @commit_list.each {|cmt| return cmt if cmt.repo_name == repo_name}
        nil
      end
      alias tracking? commit

      # returns a list of repo names being tracked
      def repo_names
        @commit_list.map {|cmt| cmt.repo_name }
      end

      private
      # a new_commit_obj is unchanged if it's sha is found to be in the
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
          return
        end
        info
      end

    end
  end
end
