require File.dirname(__FILE__) + "/../notification/notification"

class NotifyTests < Test::Unit::TestCase

  def test_libnotify_on_linux
    assert_equal "libnotify", Notification.find_notify
  end

end
