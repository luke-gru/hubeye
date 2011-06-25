begin
  require 'autotest'
rescue LoadError
  require 'rubygems'
  gem 'autotest-notification'
  require 'autotest'
end

module Autotest::Growl

  EXPIRATION_IN_SECONDS = 2
  dir =  File.dirname(__FILE__)
  CHANGE_ICON = File.expand_path(dir + "/../images/change_icon.jpg")

  def self.growl(title, msg, img, pri=0, stick="")
    system "growlnotify  -n autotest --image #{img} -p #{pri} -m #{msg.inspect} #{title} #{stick}"
  end

end
