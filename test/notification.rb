class NotifyTests < Test::Unit::TestCase
  include Hubeye::Notifiable

  if RUBY_PLATFORM =~ /linux/i
    def test_libnotify_on_linux
      assert_equal :libnotify, Notification.type
    end
  end

  if RUBY_PLATFORM =~ /darwin/i
    def test_growl_returns_on_darwin
      assert_equal :growl, Notification.type
    end
  end

end
