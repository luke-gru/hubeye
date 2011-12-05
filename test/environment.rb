class EnvironmentTests < Test::Unit::TestCase
  include Environment

  def test_proper_rootdir
    assert_equal File.expand_path(File.dirname(__FILE__) + '/..'), ROOTDIR
  end

  def test_proper_libdir
    assert_equal File.join(File.expand_path(File.dirname(__FILE__) + '/..'), 'lib'), LIBDIR
  end

  def test_proper_bindir
    assert_equal File.join(File.expand_path(File.dirname(__FILE__) + '/..'), 'bin'), BINDIR
  end

end

