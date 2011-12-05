module Notification
  include Environment

  CHANGE_ICON      = "change_icon.jpg"
  CHANGE_ICON_PATH = (File.join(ROOTDIR, "images", CHANGE_ICON))

  class Finder
    def self.find_notify
      if RUBY_PLATFORM =~ /mswin/
        return
      elsif RUBY_PLATFORM =~ /linux/
        libnotify = system('locate libnotify-bin > /dev/null')
        if libnotify
          require_relative "gnomenotify"
          return "libnotify"
        elsif LibCheck.autotest_notification
          require_relative "growl"
          return "growl"
        end
      elsif RUBY_PLATFORM =~ /darwin/i and LibCheck.autotest_notification
          require_relative "growl"
          return "growl"
      end
    end
  end

  class LibCheck
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
          true
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
          true
        end
      end
    end
  end

end # end module

