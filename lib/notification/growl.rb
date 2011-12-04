module Autotest
  module Growl

    EXPIRATION_IN_SECONDS = 2
    IMG = ::Notification::CHANGE_ICON_PATH

    def self.growl(title, msg, img=IMG, pri=0, stick="")
      system "growlnotify  -n autotest --image #{img} -p #{pri} -m #{msg.inspect} #{title} #{stick}"
    end

  end
end
