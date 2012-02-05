require "hubeye/shared/hubeye_protocol"
require "hubeye/log/logger"
require "hubeye/helpers/time"

include Hubeye::Helpers::Time
include Hubeye::Log

module Hubeye
  module Server
    attr_accessor :remote_connection
    attr_reader :socket, :sockets, :tracker, :session, :daemonized

    require 'yaml'
    require 'json'
    require 'open-uri'
    require 'forwardable'

    require_relative "commit"
    require_relative "session"

    require "hubeye/config/parser"
    require "hubeye/notification/finder"
    require "hubeye/hooks/git_hooks"
    require "hubeye/hooks/executer"

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
      CONFIG[:desktop_notification] =
        Notification::Finder.find_notify
    end

    class Exit
      def call
        socket.deliver "Bye!"
        # mark the session as continuous to not wipe the log file
        session.continuous = true
        server.remote_connection = false
        Logger.log "Closing connection to #{socket.peeraddr[2]}"
        unless tracker.empty?
          Logger.log "Tracking: #{tracker.repo_names.join ', '}"
        end
        Logger.log ""
        sockets.delete(socket)
        socket.close
      end
    end

    class Shutdown
      def call
        Logger.log "Closing connection to #{socket.peeraddr[2]}"
        Logger.log "Shutting down... (#{NOW})"
        Logger.log ""
        Logger.log ""
        socket.deliver "Shutting down server"
        sockets.delete(socket)
        socket.close
        unless server.daemonized
          STDOUT.puts "Shutting down gracefully."
        end
        exit 0
      end
    end

    class SaveHook
      def call
        hooks = session.hooks
        if !hooks.empty?
          file = "#{ENV['HOME']}/.hubeye/hooks/#{@matches[2]}.yml"
          if File.exists? file
            override?
          end
          File.open(file, "w") do |f_out|
            ::YAML.dump(hooks, f_out)
          end
          socket.deliver "Saved hook#{@matches[1]} as #{@matches[2]}"
        else
          socket.deliver "No hook#{@matches[1]} to save"
        end
      end

      private
      def override?
      end
    end

    class SaveRepo
      def call
        if !tracker.empty?
          file = "#{ENV['HOME']}/.hubeye/repos/#{@matches[2]}.yml"
          if File.exists? file
            override?
          end
          # dump only the repository names, not the shas
          File.open(file, "w") do |f_out|
            ::YAML.dump(tracker.repo_names, f_out)
          end
          socket.deliver "Saved repo#{@matches[1]} as #{@matches[2]}"
        else
          socket.deliver "No remote repos are being tracked"
        end
      end

      private
      def override?
      end
    end

    class LoadHook
      def call
        if _t = @options[:internal]
          @silent = _t
        end
        hookfile = "#{ENV['HOME']}/.hubeye/hooks/#{@matches[2]}.yml"
        new_hooks = nil
        if File.exists?(hookfile)
          File.open(hookfile) do |f|
            new_hooks = ::YAML.load(f)
          end
          # need to fix this to check if there are already commands for that
          # repo
          session.hooks.merge!(new_hooks)
          unless @silent
            socket.deliver "Loaded #{@matches[1]} #{@matches[2]}"
          end
        else
          unless @silent
            socket.deliver "No #{@matches[1]} file to load from"
          end
        end
      end
    end

    class LoadRepo
      def call
        if _t = @options[:internal]
          @silent = _t
        end
        if File.exists?(repo_file = "#{ENV['HOME']}/.hubeye/repos/#{@matches[2]}.yml")
          new_repos = nil
          File.open(repo_file) do |f|
            new_repos = ::YAML.load(f)
          end
          if !new_repos
            socket.deliver "Unable to load #{@matches[2]}: empty file" unless @silent
            return
          end
          new_repos.each do |r|
            tracker << r
          end
          unless @silent
            socket.deliver "Loaded #{@matches[2]}.\nTracking:\n#{tracker.repo_names}"
          end
        else
          socket.deliver "No file to load from"  unless @silent
        end
      end
    end

    class AddHook
      def call
        cwd   = File.expand_path('.')
        repo  = @matches[1]
        _dir  = @matches[3]
        cmd   = @matches[4]
        hooks = session.hooks
        if repo.nil? and cmd.nil?
          socket.deliver "Format: 'hook add user/repo [dir: /my/dir/repo ] cmd: some_cmd'"
          return
        end
        if hooks[repo]
          _dir ? dir = _dir : dir = cwd
          if hooks[repo][dir]
            hooks[repo][dir] << cmd
          else
            hooks[repo][dir] = [cmd]
          end
        else
          dir = _dir || cwd
          hooks[repo] = {dir => [cmd]}
        end
        socket.deliver "Hook added"
      end
    end

    class ListHooks
      def call
        hooks = session.hooks
        if hooks.empty?
          socket.deliver "No hooks"
          return
        end
        pwd = File.expand_path('.')
        format_string = ""
        hooks.each do |repo, hash|
          local_dir = nil
          command = nil
          hash.each do |dir,cmd|
            if dir.nil?
              local_dir = pwd
              command = cmd.join("\n" + (' ' * 8))
            else
              command = cmd
              local_dir = dir
            end
          end
          format_string << <<EOS
remote: #{repo}
dir:    #{local_dir}
cmds:   #{command}\n
EOS
        end
        socket.deliver format_string
      end
    end

    class ListTracking
      def call
        output = ''
        if @options[:details]
          commit_list = tracker.commit_list
          commit_list.each do |cmt|
            output << cmt.repo_name + "\n"
            underline = '=' * cmt.repo_name.length
            output << underline + "\n\n"
            output << cmt.message + "\n=> " + cmt.committer_name + "\n"
            output << "\n" unless cmt.repo_name == commit_list.last.repo_name
          end
        else
          output << tracker.repo_names.join(', ')
        end
        output = "none" if output.empty?
        socket.deliver output
      end
    end

    class Next
      def call
        socket.deliver ""
      end
    end

    class RmRepo
      def call
        username  = session.username
        repo_name = session.repo_name
        m1 = @matches[1]
        if m1.include?('/')
          username, repo_name = m1.split('/')
        else
          repo_name = m1
        end
        full_repo_name = "#{username}/#{repo_name}"
        rm = tracker.delete(full_repo_name)
        if rm
          socket.deliver "Stopped watching repository #{full_repo_name}"
        else
          socket.deliver "Repository #{full_repo_name} not currently being watched"
        end
      end
    end

    class AddRepo
      def call
        if @options and @options[:fullpath]
          session.username, session.repo_name = input.split('/')
        else
          session.repo_name = input
        end
        add_repo
      end

      private
      def add_repo
        full_repo_name = "#{session.username}/#{session.repo_name}"
        change_state = tracker << full_repo_name
        if change_state[:unchanged]
          socket.deliver "Repository #{full_repo_name} has not changed"
          return
        end
        commit = tracker.last
        msg = "#{commit.message}\n=> #{commit.committer_name}"
        if change_state[:added]
          Logger.log("Added to tracker: #{full_repo_name} (#{NOW})")
          socket.deliver msg
        elsif change_state[:replaced]
          change_msg = "New commit on #{full_repo_name}\n"
          change_msg << msg
          socket.deliver change_msg
          if server.daemonized
            Logger.log_change(full_repo_name, commit_msg, committer)
          else
            Logger.log_change(full_repo_name, commit_msg, committer,
                              :include_terminal => true)
          end
        end
      end
    end

    class Strategy
      attr_reader :server, :input

      UnknownStrategy = Class.new(StandardError)
      extend Forwardable
      def_delegators :@server, :tracker, :session, :sockets, :socket

      def initialize(server, options={})
        @server = server
        opts = {:internal_input => nil}.merge options
        invalid_input = lambda {
          @server.remote_connection = false
          throw(:invalid_input)
        }

        if !opts[:internal_input]
          begin
            @input = socket.read_all
          rescue => e
            STDOUT.puts e
            invalid_input.call
          end
          # check if the client pressed ^C or ^D
          if @input.nil?
            invalid_input.call
          end
        else
          @input = opts[:internal_input]
        end
        @input = @input.strip.downcase
        @input.gsub! /diiv/, '/'
      end

      STRATEGY_CLASSES = [ "Shutdown", "Exit", "SaveHook", "SaveRepo",
        "LoadHook", "LoadRepo", "AddHook", "ListHooks", "ListTracking",
        "Next", "RmRepo", "AddRepo" ]

      STRATEGY_CLASSES.each do |klass_str|
        klass = eval "::Hubeye::Server::#{klass_str}"
        klass.class_eval do
          extend Forwardable
          def_delegators :@strategy, :input
          def_delegators :@server, :tracker, :session, :sockets, :socket
          def initialize matches, strategy, options={}
            @matches  = matches
            @strategy = strategy
            @options  = options
            @server   = @strategy.server
            call
          end
        end
      end

      # strategy classes

      # STRATEGIES hash
      # ===============
      # keys: input matches
      # OR
      # lambda {|input| input.something?} => value
      #
      # values: lambda {|matchdata, basestrategy| SomeStrategy.new(matchdata, basestrategy)}
      STRATEGIES = {
        %r{\Ashutdown\Z} => lambda {|m, s| Shutdown.new(m, s)},
        %r{\Aquit|exit\Z} => lambda {|m, s| Exit.new(m, s)},
        %r{\Atracking\s*\Z} => lambda {|m, s| ListTracking.new(m, s)},
        %r{\Atracking\s*-d\Z} => lambda {|m, s| ListTracking.new(m, s, :details => true)},
        %r{\A\s*save hook(s?) as (.+)\Z} => lambda {|m, s| SaveHook.new(m, s)},
        %r{\A\s*save repo(s?) as (.+)\Z} => lambda {|m, s| SaveRepo.new(m, s)},
        %r{\A\s*load hook(s?) (.+)\Z} => lambda {|m, s| LoadHook.new(m, s)},
        %r{\A\s*load repo(s?) (.+)\Z} => lambda {|m, s| LoadRepo.new(m, s)},
        %r{\A\s*internal load hook(s?) (.+)\Z} => lambda {|m, s| LoadHook.new(m, s, :internal => true)},
        %r{\A\s*internal load repo(s?) (.+)\Z} => lambda {|m, s| LoadRepo.new(m, s, :internal => true)},
        %r{\Ahook add ([-\w]+/[-\w]+) (dir:\s?(.*))?\s*cmd:\s?(.*)\Z} => lambda {|m, s| AddHook.new(m, s)},
        %r{\Ahook list\Z} => lambda {|m, s| ListHooks.new(m, s)},
        %r{^\s*$} => lambda {|m, s| Next.new(m, s)},
        %r{\Arm ([-\w]+/?[-\w]*)\Z} => lambda {|m, s| RmRepo.new(m, s)},
        lambda {|inp| inp.include? '/'} => lambda {|m, s| AddRepo.new(m, s, :fullpath => true)},
        lambda {|inp| not inp.nil?} => lambda {|m, s| AddRepo.new(m, s)}
      }

      def call
        STRATEGIES.each do |inp,strat|
          if inp.respond_to? :match
            if m = @input.match(inp)
              return strat.call(m, self)
            end
          elsif inp.respond_to? :call
            if m = inp.call(@input)
              return strat.call(m, self)
            end
          end
        end
        raise UnknownStrategy
      end
    end # end of Strategy

    # main server loop
    def start(port, options={})
      listen(port)
      setup_env(options)
      loop do
        waiting = catch(:connect) do
          look_for_changes unless @remote_connection
        end
        client_connect(@sockets) if waiting
        catch(:invalid_input) do
          strategy = Strategy.new(self)
          strategy.call
        end
        @session.cleanup!
      end
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
      @tracker = Tracker.new(self)
      unless CONFIG[:default_track].empty?
        repos = CONFIG[:default_track]
        repos.each do |repo|
          @tracker << repo
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
          STDOUT.puts
          exit 1
        end
      end
    end

    def session_load options={}
      opts = {:hooks => nil, :repos => nil}.merge options
      if hooks = opts[:hooks]
        hooks.each do |h|
          strat = Strategy.new(self, :internal_input => "internal load hook #{h}")
          strat.call
        end
      elsif repos = opts[:repos]
        repos.each do |r|
          strat = Strategy.new(self, :internal_input => "internal load repo #{r}")
          strat.call
        end
      else
        raise ArgumentError.new "Must load either hooks or repos"
      end
    end

    #TODO: refactor this ugly, long method into a new class
    def look_for_changes
      if @sockets.size != 1 and @tracker.empty?
        @remote_connection = client_ready(@sockets, :block => true) ? true : false
        throw(:connect, true) if @remote_connection
      end
      sleep_amt = CONFIG[:oncearound] / @tracker.length
      loop do
        @tracker.repo_names do |repo_name|
          start_time = Time.now
          change_state = @tracker << repo_name
          api_time = (Time.now - start_time).to_i
          if change_state[:unchanged]
            (sleep_amt - api_time).times do
              sleep 1
              @remote_connection = client_ready(@sockets) ? true : false
              throw(:connect, true) if @remote_connection
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
            when "libnotify"
              Notification::GnomeNotify.notify("Hubeye", change_msg)
            when "growl"
              Autotest::Growl.growl("Hubeye", change_msg)
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
        select(sockets, nil, nil)
      else
        select(sockets, nil, nil, 1)
      end
    end

    def client_connect(sockets)
      ready = select(sockets)
      readable = ready[0]
      readable.each do |socket|
        if socket == @tcp_server
          @socket = @tcp_server.accept
          @socket.sync = false
          sockets << @socket
          # Inform the client of connection
          basic_inform = "Hubeye running on #{Socket.gethostname} as #{@session.username}"
          if !@tracker.empty?
            @socket.deliver "#{basic_inform}\nTracking: #{@tracker.repo_names.join ', '}"
          else
            @socket.deliver basic_inform
          end
          puts "Client connected at #{NOW}" unless @daemonized
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
