begin
  require 'autotest'
rescue LoadError
  require 'rubygems'
  gem 'autotest-notification'
  require 'autotest'
end

module Autotest::GnomeNotify

  EXPIRATION_IN_SECONDS = 2
  dir =  File.dirname(__FILE__)
  CHANGE_ICON = dir + "../images/change_icon.jpg"

  def self.notify(title, msg, img)
    options = "-t #{EXPIRATION_IN_SECONDS * 1000} -i #{img}"
    system "notify-send #{options} '#{title}' '#{msg}'"
  end

end
