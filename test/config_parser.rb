# Hubeye::Config::Parser.new uses StringIO.open() when option :test => true is set
require 'stringio'

class ConfigParserTests < Test::Unit::TestCase

  # otherwise, Test::Unit busies the object.instance_variables
  # array with things like @passed, and many others
  def instance_vars
    [:@username, :@default_track, :@hooks,
     :@repos, :@oncearound, :@notification_wanted]
  end

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
    other_vars = instance_vars.reject {|v| v =~ /username/}
    other_vars.each {|v| assert_nil instance_variable_get(v)}

    assert_equal 'luke-gru', @username
  end

  def test_proper_default_track_parse
    text = 'track: rails/rails, jimweirich/rake, sinatra/sinatra'
    get_config_settings(text)
    other_vars = instance_vars.reject {|v| v =~ /default_track/}
    other_vars.each {|v| assert_nil instance_variable_get(v)}

    assert_equal 3, @default_track.length
    assert_equal ['rails/rails', 'jimweirich/rake', 'sinatra/sinatra'], @default_track
  end

  def test_username_and_default_track_parse
    text = "username: luke-gru\n" +
           "track: rails/rails, jimweirich/rake, sinatra/sinatra"
    get_config_settings(text)
    other_vars = instance_vars.reject {|v| v =~ /default_track|username/}
    other_vars.each {|v| assert_nil instance_variable_get(v)}

    assert_equal 'luke-gru', @username
    assert_equal ['rails/rails', 'jimweirich/rake', 'sinatra/sinatra'], @default_track
  end

  def test_oncearound_error
    text = 'oncearound: fooey'
    assert_raises(Hubeye::Config::Parser::ConfigParseError) { get_config_settings(text) }
  end

  def test_proper_oncearound_parse
    text = 'oncearound: 80'
    get_config_settings(text)
    other_vars = instance_vars.reject {|v| v =~ /oncearound/}
    other_vars.each {|v| assert_nil instance_variable_get(v)}

    assert_equal 80, @oncearound
  end

  def test_oncearound_and_default_track_parse_with_spaces_tabs
    text = "oncearound: 2330\n" +
           "track: luke-gru/hubeye,    sinatra/sinatra,		rails/rails"
    get_config_settings(text)
    other_vars = instance_vars.reject {|v| v =~ /oncearound|default_track/}
    other_vars.each {|v| assert_nil instance_variable_get(v)}

    assert_equal 2330, @oncearound
    assert_equal ['luke-gru/hubeye', 'sinatra/sinatra', 'rails/rails'], @default_track
  end

  def test_proper_default_hook_parse
    text = 'load hooks: myhook1, myhook2, captain_hook'
    get_config_settings(text)
    other_vars = instance_vars.reject {|v| v =~ /hooks/}
    other_vars.each {|v| assert_nil instance_variable_get(v)}

    assert_equal ['myhook1', 'myhook2', 'captain_hook'], @hooks
  end

  def test_proper_default_repos_parse
    text = 'load repos: myforks, myprojects, mywork'
    get_config_settings(text)
    other_vars = instance_vars.reject {|v| v =~ /repos/}
    other_vars.each {|v| assert_nil instance_variable_get(v)}

    assert_equal ['myforks', 'myprojects', 'mywork'], @repos
  end

  def test_notification_off_parse
    text = 'desktop notification: off'
    get_config_settings(text)
    other_vars = instance_vars.reject {|v| v =~ /notification_wanted/}
    other_vars.each {|v| assert_nil instance_variable_get(v)}

    assert_equal false, @notification_wanted
  end

  def test_notification_on_parse
    text = 'desktop notification: on'
    get_config_settings(text)
    other_vars = instance_vars.reject {|v| v =~ /notification_wanted/}
    other_vars.each {|v| assert_nil instance_variable_get(v)}

    assert_equal true, @notification_wanted

  end

  def test_notification_error
    text = 'desktop notification: fooey'
    assert_raises(Hubeye::Config::Parser::ConfigParseError) { get_config_settings(text) }
  end

  def test_all_options
    text = "oncearound: 2330\n" +
           "track: luke-gru/hubeye,    sinatra/sinatra,		rails/rails\n" +
           "desktop notification: on\n" +
           "load repos: myforks, myprojects, mywork\n" +
           "load hooks: myhook1, myhook2, captain_hook\n" +
           "username: hansolo" +
           "\n\n"
    get_config_settings(text)

    assert_equal 2330, @oncearound
    assert_equal ['luke-gru/hubeye', 'sinatra/sinatra', 'rails/rails'], @default_track
    assert @notification_wanted
    assert_equal ['myforks', 'myprojects', 'mywork'], @repos
    assert_equal ['myhook1', 'myhook2', 'captain_hook'], @hooks
    assert_equal 'hansolo', @username
  end

end

