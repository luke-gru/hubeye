module Hubeye
  module Notifiable
    class GnomeNotification

      EXPIRATION_IN_SECONDS = 2

      def initialize(title, msg, img=CHANGE_ICON_PATH)
        options = "-t #{EXPIRATION_IN_SECONDS * 1000} -i #{img}"
        system "notify-send #{options} '#{title}' '#{msg}'"
      end

    end
  end
end

