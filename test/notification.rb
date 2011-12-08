class NotifyTests < Test::Unit::TestCase
  include Hubeye::Notification

  def test_libnotify_on_linux
    if RUBY_PLATFORM =~ /linux/i
      assert_equal "libnotify", Finder.find_notify
    end
  end

  def test_growl_returns_on_darwin
    if RUBY_PLATFORM =~ /darwin/i
      assert_equal "growl", Finder.find_notify
    end
  end

end
