require "hubeye/shared/hubeye_protocol"
require "hubeye/log/logger"
require "hubeye/helpers/time"
require "hubeye/config/parser"
require "hubeye/notifiable/notification"
require "hubeye/hooks/command"
require "hubeye/hooks/git"

require File.expand_path("../strategies/decision", __FILE__)
require File.expand_path("../tracker", __FILE__)
require File.expand_path("../session", __FILE__)

include Hubeye::Helpers::Time
include Hubeye::Log

module Hubeye
  module Server
    attr_accessor :remote_connection
    attr_reader :socket, :sockets, :tracker, :session, :daemonized

    CONFIG_FILE = File.join(ENV['HOME'], ".hubeye", "hubeyerc")
    CONFIG = {}

    # CONFIG options: defined in ~/.hubeye/hubeyerc
    #
    # Option overview:
    #
    # CONFIG[:oncearound]: 60 (seconds) is the default amount of time for looking
    # for changes in every single repository. If tracking lots of repos,
    # it might be a good idea to increase the value, or hubeye will cry
    # due to overwork, fatigue and general anhedonia.
    #
    # hubeyerc format => oncearound: 1000
    #
    # CONFIG[:username] is the username used when not specified.
    # hubeyerc format => username: 'hansolo'
    # when set to 'hansolo'
    # >rails
    # would track https://www.github.com/hansolo/rails
    # but a full URI path won't use CONFIG[:username]
    # >rails/rails
    # would track https://www.github.com/rails/rails
    Config::Parser.new(CONFIG_FILE) do |c|
      CONFIG[:username]       = c.username ||
        `git config --get-regexp github`.split(' ').last || ''
      CONFIG[:oncearound]     = c.oncearound || 60
      CONFIG[:load_repos]     = c.load_repos || []
      CONFIG[:load_hooks]     = c.load_hooks || []
      CONFIG[:default_track]  = c.default_track || []

      CONFIG[:notification_wanted] = if c.notification_wanted.nil?
                                       true
                                     else
                                       c.notification_wanted
                                     end
    end

    if CONFIG[:notification_wanted]
      CONFIG[:desktop_notification] = Notifiable::Notification.type
    end

    # main server loop
    def start(port, options={})
      listen(port)
      setup_env(options)
      loop do
        unless @remote_connection
          look_for_changes
          client_connect(@sockets)
        end
        catch(:invalid_input) do
          decision = Strategies::Decision.new(self)
          decision.call_strategy
        end
        @session.cleanup!
      end
    end

    def full_repo_name(repo)
      return repo if repo.include? '/'
      [@session.username, repo].join '/'
    end

    private
    def listen(port)
      @tcp_server = TCPServer.open(port)
    end

    def setup_env(options={})
      @remote_connection = false
      @daemonized = options[:daemon]
      @sockets = [@tcp_server]
      trap_signals 'INT', 'KILL'
      @session = Session.new
      @session.username = CONFIG[:username]
      @tracker = Tracker.new
      unless CONFIG[:default_track].empty?
        repos = CONFIG[:default_track]
        repos.each do |repo|
          repo_name = full_repo_name(repo)
          @tracker << repo_name
        end
      end
      unless CONFIG[:load_hooks].empty?
        hooks = CONFIG[:load_hooks]
        session_load :hooks => hooks
      end
      unless CONFIG[:load_repos].empty?
        repos = CONFIG[:load_repos]
        session_load :repos => repos
      end
    end

    def trap_signals *sigs
      sigs.each do |sig|
        trap(sig) do
          @sockets.each {|s| s.close}
          STDOUT.print "\n"
          exit 1
        end
      end
    end

    def session_load options={}
      opts = {:hooks => nil, :repos => nil}.merge options
      if hooks = opts[:hooks]
        hooks.each do |h|
          decision = Strategies::Decision.new(self, :internal_input => "internal load hook #{h}")
          decision.call_strategy
        end
      elsif repos = opts[:repos]
        repos.each do |r|
          decision = Strategies::Decision.new(self, :internal_input => "internal load repo #{r}")
          decision.call_strategy
        end
      else
        raise ArgumentError.new "Must load either hooks or repos"
      end
    end

    def look_for_changes
      if @tracker.length.zero?
        @remote_connection = client_ready(@sockets, :block => true)
      end
      while not @remote_connection
        sleep_amt = CONFIG[:oncearound] / @tracker.length
        @tracker.repo_names.each do |repo_name|
          change_state = @tracker << repo_name
          if change_state  == :unchanged
            (sleep_amt).times do
              @remote_connection = client_ready(@sockets)
              return if @remote_connection
            end
          else
            # There was a change to a tracked repository.
            commit = @tracker.last
            full_repo_name = commit.repo
            commit_msg     = commit.message
            committer      = commit.committer_name
            new_sha        = commit.sha
            change_msg = "Repo #{full_repo_name} has changed\nNew commit: " \
              "#{commit_msg}\n=> #{committer}"
            case CONFIG[:desktop_notification]
            when :libnotify
              Notifiable::GnomeNotification.new("Hubeye", change_msg)
            when :growl
              Notifiable::GrowlNotification.new("Hubeye", change_msg)
            when nil
              unless @daemonized
                Logger.log_change(full_repo_name, commit_msg, committer, :include_terminal => true)
                already_logged = true
              end
            end
            Logger.log_change(full_repo_name, commit_msg, committer) unless
              already_logged
            # execute any hooks for that repository
            unless @session.hooks.empty?
              if hooks = @session.hooks[full_repo_name]
                hooks.each do |dir,cmds|
                  Hooks::Command.execute(cmds, :directory => dir, :repo => full_repo_name)
                end
              end
            end
          end
        end
      end
    end

    def client_ready(sockets, options={})
      if options[:block]
        r = select(sockets, nil, nil)
      else
        r = select(sockets, nil, nil, 1)
      end
      not r.nil?
    end

    def client_connect(sockets)
      ready = select(sockets)
      readable = ready[0]
      readable.each do |socket|
        if socket == @tcp_server
          @socket = @tcp_server.accept
          @socket.sync = true
          sockets << @socket
          # Inform the client of connection
          basic_inform = "Hubeye running on #{Socket.gethostname} as #{@session.username}"
          if !@tracker.empty?
            @socket.deliver "#{basic_inform}\nTracking: #{@tracker.repo_names.join ', '}"
          else
            @socket.deliver basic_inform
          end
          puts "Client connected at #{NOW[]}" unless @daemonized
          if @session.continuous
            Logger.log "Accepted connection from #{@socket.peeraddr[2]} (#{NOW})"
          else
            # wipe the log file and start fresh
            Logger.relog "Accepted connection from #{@socket.peeraddr[2]} (#{NOW})"
          end
          Logger.log "local:  #{@socket.addr}"
          Logger.log "peer :  #{@socket.peeraddr}"
        end
      end
    end

    class Server
      include ::Hubeye::Server

      def initialize(debug=true)
        @debug = debug
      end
    end
  end # of Server module
end # end of Hubeye module
