module Notification

  dir =  File.dirname(__FILE__)
  CHANGE_ICON      = "change_icon.jpg"
  CHANGE_ICON_PATH = File.expand_path(File.join(dir, "..", "images", CHANGE_ICON))

  class Finder

    def self.find_notify
      if RUBY_PLATFORM =~ /mswin/
        return
      elsif RUBY_PLATFORM =~ /linux/
        libnotify = system('locate libnotify-bin > /dev/null')

        if libnotify && LibCheck.autotest
          require_relative "gnomenotify"
          return "libnotify"
        elsif LibCheck.autotest_notification
          require_relative "growl"
          return "growl"
        else
          return
        end

      elsif RUBY_PLATFORM =~ /darwin/i

        if LibCheck.autotest_notification
          require_relative "growl"
          return "growl"
        else
          return
        end

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

