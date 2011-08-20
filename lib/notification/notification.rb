module Notification

  class Finder

    def self.find_notify
      if RUBY_PLATFORM =~ /mswin/
        return
      elsif RUBY_PLATFORM =~ /linux/
        libnotify = system('locate libnotify-bin > /dev/null')

        if libnotify && LibChecker.autotest
          require_relative "gnomenotify"
          return "libnotify"
        elsif LibChecker.autotest_notification
          require_relative "growl"
          return "growl"
        else
          return
        end

      elsif RUBY_PLATFORM =~ /darwin/i

        if LibChecker.autotest_notification
        require_relative "growl"
        return "growl"
        else
          return
        end

      end
    end

  end

  class LibChecker

    class << self
      def autotest
        begin
          require 'autotest'
        rescue LoadError
          if require 'rubygems'
            retry
          else
            return
          end
        end
        if defined? Autotest
          return true
        end
      end


      def autotest_notification
        begin
          require 'autotest_notification'
        rescue LoadError
          if require 'rubygems'
            retry
          else
            return
          end
        end
        if defined? Autotest
          return true
        end
      end
    end

  end

end # end module

