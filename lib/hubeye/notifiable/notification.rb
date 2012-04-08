module Hubeye
  module Notifiable
    include Environment

    CHANGE_ICON      = "change_icon.jpg"
    CHANGE_ICON_PATH = (File.join(ROOTDIR, "images", CHANGE_ICON))

    class Notification
      class << self

        def type
          if RUBY_PLATFORM =~ /mswin/
            return
          elsif RUBY_PLATFORM =~ /linux/
            libnotify = system('locate libnotify-bin > /dev/null 2>&1')
            if libnotify
              require File.expand_path("../gnome_notification", __FILE__)
              return :libnotify
            elsif autotest_notification?
              require File.expand_path("../growl_notification", __FILE__)
              return :growl
            end
          elsif RUBY_PLATFORM =~ /darwin/i and autotest_notification?
              require File.expand_path("../growl_notification", __FILE__)
              return :growl
          end
        end

        def autotest_notification?
          require 'rubygems'
          require 'autotest_notification'
          if defined? Autotest
            true
          end
        end

      end
    end

  end
end
