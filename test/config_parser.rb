# Hubeye::Config::Parser.new uses StringIO.open() when option {:test => true} is set
require 'stringio'

class ConfigParserTests < Test::Unit::TestCase

  def get_config_settings(config_file)
    Hubeye::Config::Parser.new(config_file, :test => true) do |c|
      @username = c.username
      @default_track = c.default_track
      @hooks = c.load_hooks
      @repos = c.load_repos
      @oncearound = c.oncearound
      @notification_wanted = c.notification_wanted
    end
  end

  def test_proper_username_parse
    text = 'username: luke-gru'
    get_config_settings(text)
    assert_nil @default_track
    assert_nil @oncearound
    assert_nil @hooks
    assert_nil @notification_wanted
    assert_nil @repos

    assert_equal 'luke-gru', @username
  end

  def test_proper_default_track_parse
    text = 'track: rails/rails, jimweirich/rake, sinatra/sinatra'
    get_config_settings(text)
    assert_nil @username
    assert_nil @oncearound
    assert_nil @hooks
    assert_nil @notification_wanted
    assert_nil @repos

    assert_equal 3, @default_track.length
    assert_equal ['rails/rails', 'jimweirich/rake', 'sinatra/sinatra'], @default_track
  end

  def test_oncearound_error
    text = 'oncearound: fooey'
    assert_raises(Hubeye::Config::Parser::ConfigParseError) { get_config_settings(text) }
  end

  def test_proper_oncearound_parse
    text = 'oncearound: 80'
    get_config_settings(text)
    assert_nil @username
    assert_nil @default_track
    assert_nil @hooks
    assert_nil @notification_wanted
    assert_nil @repos

    assert_equal 80, @oncearound
  end

  def test_proper_default_hook_parse
    text = 'load hooks: myhook1, myhook2, captain_hook'
    get_config_settings(text)
    assert_nil @username
    assert_nil @oncearound
    assert_nil @default_track
    assert_nil @notification_wanted
    assert_nil @repos

    assert_equal ['myhook1', 'myhook2', 'captain_hook'], @hooks
  end

  def test_proper_default_repos_parse
    text = 'load repos: myforks, myprojects, mywork'
    get_config_settings(text)
    assert_nil @username
    assert_nil @oncearound
    assert_nil @default_track
    assert_nil @notification_wanted
    assert_nil @hooks

    assert_equal ['myforks', 'myprojects', 'mywork'], @repos
  end

  def test_notification_off_parse
    text = 'desktop notification: off'
    get_config_settings(text)
    assert_nil @username
    assert_nil @oncearound
    assert_nil @default_track
    assert_nil @hooks
    assert_nil @repos

    assert_equal false, @notification_wanted
  end

  def test_notification_on_parse
    text = 'desktop notification: on'
    get_config_settings(text)
    assert_nil @username
    assert_nil @oncearound
    assert_nil @default_track
    assert_nil @hooks
    assert_nil @repos

    assert_equal true, @notification_wanted

  end

  def test_notification_error
    text = 'desktop notification: fooey'
    assert_raises(Hubeye::Config::Parser::ConfigParseError) { get_config_settings(text) }
  end

end

