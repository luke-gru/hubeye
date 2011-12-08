module Hubeye
  module Server
    class Session
      attr_accessor :repo_name, :username, :continuous
      attr_writer :tracker, :hooks

      def initialize
        setup_singleton_methods
      end

      def tracker
        @tracker ||= {}
      end

      def hooks
        @hooks ||= {}
      end

      def cleanup
        reset_username
        reset_repo_name
      end

      private
      def reset_username
        self.username = CONFIG[:username]
      end

      def reset_repo_name
        self.repo_name = ""
      end

      def setup_singleton_methods
        tracker.singleton_class.class_eval do
          def add_or_replace! input, new_sha=nil
            if Hash === input and new_sha.nil?
              repo = input.keys.first
              hash = true
            else
              repo = input
              two_args = true
            end
            if keys.include? repo and self[repo] == new_sha
              return
            elsif keys.include? repo
              ret = {:replace => true}
            else
              ret = {:add => true}
            end
            two_args ? merge!(repo => new_sha) : merge!(input)
            ret
          end
        end
      end

    end # end of Session class
  end
end

