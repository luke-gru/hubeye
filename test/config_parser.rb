# Hubeye::Config::Parser.new uses StringIO.open() when option {:test => true} is set
require 'stringio'

class ConfigParserTests < Test::Unit::TestCase

  def get_config_settings(config_file)
    Hubeye::Config::Parser.new(config_file, :test => true) do |c|
      @username = c.username
      @to_track = c.track
      @oncearound = c.oncearound
      @hooks = c.hooks
    end
  end

  def test_proper_username_parse
    text = 'username: luke-gru'
    get_config_settings(text)
    assert_nil @to_track
    assert_nil @oncearound
    assert_nil @hooks

    assert_equal 'luke-gru', @username
  end

  def test_proper_default_repo_parse
    text = 'track: rails/rails, jimweirich/rake, sinatra/sinatra'
    get_config_settings(text)
    assert_nil @username
    assert_nil @oncearound
    assert_nil @hooks

    assert_equal 3, @to_track.length
    assert_equal ['rails/rails', 'jimweirich/rake', 'sinatra/sinatra'], @to_track
  end

  def test_proper_oncearound_parse
    text = 'oncearound: 80'
    get_config_settings(text)
    assert_nil @username
    assert_nil @to_track
    assert_nil @hooks

    assert_equal 80, @oncearound
  end

  def test_proper_default_hook_parse
    text = 'hooks: myhook1, myhook2, captain_hook'
    get_config_settings(text)
    assert_nil @username
    assert_nil @oncearound
    assert_nil @to_track

    assert_equal ['myhook1', 'myhook2', 'captain_hook'], @hooks
  end

end

