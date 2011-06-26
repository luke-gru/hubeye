module Notification
  def self.find_notify
    if RUBY_PLATFORM =~ /mswin/

    elsif RUBY_PLATFORM =~ /linux/
      libnotify = system('locate libnotify-bin > /dev/null')
      if libnotify
        require_relative "gnomenotify"
        return "libnotify"
      else
        raise "libnotify-bin needs to be installed in order to receive Desktop notifications."
      end
    elsif RUBY_PLATFORM =~ /darwin/i
      require_relative "growl"
      return "growl"
    end
  end
end
