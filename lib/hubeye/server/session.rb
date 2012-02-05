module Hubeye
  module Server
    class Session
      attr_accessor :repo_name, :username, :continuous
      attr_writer   :hooks

      def initialize
        defaults!
      end

      def hooks
        @hooks ||= {}
      end

      def defaults!
        reset_username
        reset_repo_name
      end
      alias cleanup! defaults!

      private
      def reset_username
        self.username = CONFIG[:username]
      end

      def reset_repo_name
        self.repo_name = ""
      end

    end
  end
end

