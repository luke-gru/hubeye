require File.dirname(__FILE__) + "/../notification/notification"

class NotifyTests < Test::Unit::TestCase

  def test_libnotify_on_linux
    if RUBY_PLATFORM =~ /linux/i
    assert_equal "libnotify", Notification.find_notify
    end
  end

  def test_growl_returns_on_darwin
    if RUBY_PLATFORM =~ /darwin/i
    assert_equal "growl", Notification.find_notify
    end
  end

end
