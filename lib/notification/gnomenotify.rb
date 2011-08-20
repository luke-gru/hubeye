module Autotest::GnomeNotify

  EXPIRATION_IN_SECONDS = 2
  CHANGE_ICON = File.join(File.expand_path("images", ::Environment::ROOTDIR), "change_icon.jpg")

  def self.notify(title, msg, img)
    options = "-t #{EXPIRATION_IN_SECONDS * 1000} -i #{img}"
    system "notify-send #{options} '#{title}' '#{msg}'"
  end

end
