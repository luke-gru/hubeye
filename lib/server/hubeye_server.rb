require "log/logger"
include Log

class Hubeye

  # simple interface to Github's api v3 for commits
  class Commit
    attr_reader :raw_input, :repo, :only_sha, :latest
    def initialize(input)
      @raw_input = input
      @repo = input.keys.first
      if Hash === input
        if input[@repo].keys == ["sha"]
          @only_sha = true
        else
          @latest = true
        end
      else
        raise ArgumentError.new "input must be a kind of hash"
      end
    end

    def sha
      @sha ||= @raw_input[@repo]['sha']
    end

    def commit_message
      if @only_sha
        return
      elsif @latest
        @commit_message ||= @raw_input[@repo]['commit']['message']
      else
        raise
      end
    end

    def committer_name
      if @only_sha
        return
      elsif @latest
        @committer_name ||= @raw_input[@repo]['commit']['committer']['name']
      else
        raise
      end
    end
  end

  module Server
    attr_accessor :remote_connection
    attr_reader :socket, :sockets, :session, :daemonized

    # standard lib.
    require 'socket'
    require 'yaml'
    require 'json'
    require 'open-uri'
    # hubeye
    require "config/parser"
    require "notification/finder"
    require "hooks/git_hooks"
    require "hooks/executer"
    require "helpers/time"
    include Helpers::Time

    CONFIG_FILE = File.join(ENV['HOME'], ".hubeye", "hubeyerc")
    CONFIG = {}
    # find Desktop notification system

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
        `git config --get-regexp github`.split(' ').last
      CONFIG[:oncearound]     = c.oncearound || 60
      CONFIG[:load_repos]     = c.load_repos || []
      CONFIG[:load_hooks]     = c.load_hooks || []
      CONFIG[:default_track]  = c.default_track || nil

      CONFIG[:notification_wanted] = if c.notification_wanted.nil?
                                       true
                                     else
                                       c.notification_wanted
                                     end
    end

    CONFIG[:desktop_notification] = Notification::Finder.find_notify if
    CONFIG[:notification_wanted]

    class Strategy
      UnknownStrategy = Class.new(StandardError)
      attr_reader :server, :input

      def initialize(server, options={})
        @server = server
        opts = {:internal_input => nil}.merge options
        if !opts[:internal_input]
          @input = server.socket.gets
          # check if the client pressed ^C or ^D
          if @input.nil?
            @server.remote_connection = false
            throw(:invalid_input)
          end
          @input.chop!
        else
          @input = opts[:internal_input]
        end
        unless @input
          Logger.log "Client on #{@server.socket.peeraddr[2]} disconnected."
          @server.sockets.delete(socket)
          @server.socket.close
          return
        end
        @input = @input.strip.downcase
        @input.gsub! /diiv/, '/'
      end

      STRATEGY_CLASSES = [ "Shutdown", "Exit", "SaveHook", "SaveRepo",
        "LoadHook", "LoadRepo", "AddHook", "ListHooks", "ListTracking",
        "Next", "RmRepo", "AddRepo" ]


      STRATEGY_CLASSES.each do |klass_str|
        binding.eval "class #{klass_str}; end"
        klass = const_get klass_str.intern
        klass.class_eval do
          def initialize matches, strategy, options={}
            @options  = options
            @matches  = matches
            @server   = strategy.server
            @input    = strategy.input
            @socket   = @server.socket
            @sockets  = @server.sockets
            @session  = @server.session
            call
          end
        end
      end

      # strategy classes
      class Exit
        def call
          @socket.puts "Bye!"
          # mark the session as continuous to not wipe the log file
          @session.continuous = true
          Logger.log "Closing connection to #{@socket.peeraddr[2]}"
          @server.remote_connection = false
          if !@session.tracker.empty?
            Logger.log "Tracking: #{@session.tracker.keys.join ', '}"
          end
          # to look pretty when multiple connections per loop
          Logger.log ""
          @sockets.delete(@socket)
          @socket.close
        end
      end

      class Shutdown
        def call
          Logger.log "Closing connection to #{@socket.peeraddr[2]}"
          Logger.log "Shutting down... (#{::Hubeye::Server::NOW})"
          Logger.log ""
          Logger.log ""
          @socket.puts("Shutting down server")
          @sockets.delete(@socket)
          @socket.close
          unless @server.daemonized
            STDOUT.puts "Shutting down gracefully."
          end
          exit 0
        end
      end

      class SaveHook
        def call
          hooks = @session.hooks
          if !hooks.empty?
            file = "#{ENV['HOME']}/.hubeye/hooks/#{@matches[2]}.yml"
            if File.exists? file
              override?
            end
            File.open(file, "w") do |f_out|
              ::YAML.dump(hooks, f_out)
            end
            @socket.puts("Saved hook#{@matches[1]} as #{@matches[2]}")
          else
            @socket.puts("No hook#{@matches[1]} to save")
          end
        end

        private
        def override?
        end
      end

      class SaveRepo
        def call
          if !@session.tracker.empty?
            file = "#{ENV['HOME']}/.hubeye/repos/#{@matches[2]}.yml"
            if File.exists? file
              override?
            end
            # dump only the repository names, not the shas
            File.open(file, "w") do |f_out|
              ::YAML.dump(@session.tracker.keys, f_out)
            end
            @socket.puts("Saved repo#{@matches[1]} as #{@matches[2]}")
          else
            @socket.puts("No remote repos are being tracked")
          end
        end

        private
        def override?
        end
      end

      class LoadHook
        def call
          if @options[:internal]
            @silent = @options[:internal]
          end
          hookfile = "#{ENV['HOME']}/.hubeye/hooks/#{@matches[2]}.yml"
          new_hooks = nil
          if File.exists?(hookfile)
            File.open(hookfile) do |f|
              new_hooks = ::YAML.load(f)
            end
            @session.hooks.merge!(new_hooks)
            unless @silent
              @socket.puts("Loaded #{@matches[1]} #{@matches[2]}")
            end
          else
            unless @silent
              @socket.puts("No #{@matches[1]} file to load from")
            end
          end
        end
      end

      class LoadRepo
        def call
          if @options[:internal]
            @silent = @options[:internal]
          end
          if File.exists?(repo_file = "#{ENV['HOME']}/.hubeye/repos/#{@matches[2]}.yml")
            new_repos = nil
            File.open(repo_file) do |f|
              new_repos = ::YAML.load(f)
            end
            if !new_repos
              @socket.puts "Unable to load #{@matches[2]}: empty file" unless @silent
              return
            end
            new_repos.each do |r|
              # add the repo name to the hubeye tracker
              commit = @server.track(r)
              @session.tracker.add_or_replace!(commit.repo, commit.sha)
            end
            unless @silent
              @socket.puts "Loaded #{@matches[2]}.\nTracking:\n#{@session.tracker.keys.join ', '}"
            end
          else
            @socket.puts("No file to load from") unless @silent
          end
        end
      end

      class AddHook
        def call
          cwd  = File.expand_path('.')
          repo = @matches[1]
          dir  = @matches[3]
          cmd  = @matches[4]
          if repo != nil and cmd != nil
            if @session.hooks[repo]
              if dir
                if @session.hooks[repo][dir]
                  @session.hooks[repo][dir] << cmd
                else
                  @session.hooks[repo][dir] = [cmd]
                end
              else
                if @session.hooks[repo][cwd]
                  @session.hooks[repo][cwd] << cmd
                else
                  @session.hooks[repo][cwd] = [cmd]
                end
              end
            else
              if dir
                @session.hooks[repo] = {dir => [cmd]}
              else
                @session.hooks[repo] = {cwd => [cmd]}
              end
            end
            @socket.puts("Hook added")
          else
            @socket.puts("Format: 'hook add user/repo [dir: /my/dir/repo ] cmd: git pull origin'")
          end
        end
      end

      class ListHooks
        def call
          unless @session.hooks.empty?
            pwd = File.expand_path('.')
            format_string = ""
            @session.hooks.each do |repo, hash|
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
            @socket.puts(format_string)
          else
            @socket.puts("No hooks")
          end
        end
      end

      class ListTracking
        def call
          output = ''
          if @options[:details]
            commit_list = []
            @session.tracker.keys.each do |repo|
              commit = @server.track(repo, :list => true)
              commit_list << commit
            end
            commit_list.each do |c|
              output << c.repo + "\n"
              underline = '=' * c.repo.length
              output << underline + "\n"
              output << c.commit_message + "\n=> " +
                c.committer_name + "\n"
              output << "\n" unless c.repo == commit_list.last.repo
            end
          else
            output << @session.tracker.keys.join(', ')
          end
          output = "none" if output.empty?
          @socket.puts(output)
        end
      end

      class Next
        def call
          @socket.puts("")
        end
      end

      class RmRepo
        def call
          if @matches[1].include?("/")
            @session.username, @session.repo_name = @matches[1].split('/')
          else
            @session.repo_name = @matches[1]
          end
          rm = @session.tracker.delete("#{@session.username}/#{@session.repo_name}")
          if rm
            @socket.puts("Stopped watching repository #{@session.username}/#{@session.repo_name}")
          else
            @socket.puts("Repository #{@session.username}/#{@session.repo_name} not currently being watched")
          end
        end
      end

      class AddRepo
        def call
          if @options and @options[:pwd]
            @session.repo_name = File.dirname(File.expand_path('.'))
          elsif @options and @options[:fullpath]
            @session.username, @session.repo_name = @input.split('/')
          else
            @session.repo_name = @input
          end
          add_repo
        end

        private
        def add_repo
          full_repo_name = "#{@session.username}/#{@session.repo_name}"
          commit = @server.track(full_repo_name, :latest => true)
          new_sha = commit.sha
          commit_msg = commit.commit_message
          committer  = commit.committer_name
          msg = "#{commit_msg}\n=> #{committer}"
          change = @session.tracker.add_or_replace!(full_repo_name, new_sha)
          # new repo to track
          if !change
            @socket.puts("Repository #{full_repo_name} has not changed")
            return
          elsif change[:add]
            # log the fact that the user added a repo to be tracked
            Logger.log("Added to tracker: #{full_repo_name} (#{::Hubeye::Server::NOW})")
            # show the user, via the client, the info and commit msg for the commit
            @socket.puts(msg)
          elsif change[:replace]
            change_msg = "New commit on #{full_repo_name}\n"
            change_msg << msg
            @socket.puts(change_msg)
            if @server.daemonized
              Logger.log_change(full_repo_name, commit_msg, committer)
            else
              Logger.log_change(full_repo_name, commit_msg, committer,
                                :include_terminal => true)
            end
          end
        end
      end

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
        %r{\A\s*save hook(s?) as (.+)\Z} => lambda {|m, s| SaveHook.new(m, s)},
        %r{\A\s*save repo(s?) as (.+)\Z} => lambda {|m, s| SaveRepo.new(m, s)},
        %r{\A\s*load hook(s?) (.+)\Z} => lambda {|m, s| LoadHook.new(m, s)},
        %r{\A\s*load repo(s?) (.+)\Z} => lambda {|m, s| LoadRepo.new(m, s)},
        %r{\A\s*internal load hook(s?) (.+)\Z} => lambda {|m, s| LoadHook.new(m, s, :internal => true)},
        %r{\A\s*internal load repo(s?) (.+)\Z} => lambda {|m, s| LoadRepo.new(m, s, :internal => true)},
        %r{\Ahook add ([-\w]+/[-\w]+) (dir:\s?(.*))?\s*cmd:\s?(.*)\Z} => lambda {|m, s| AddHook.new(m, s)},
        %r{\Ahook list\Z} => lambda {|m, s| ListHooks.new(m, s)},
        %r{\Atracking\s*\Z} => lambda {|m, s| ListTracking.new(m, s)},
        %r{\Atracking\s*-d\Z} => lambda {|m, s| ListTracking.new(m, s, :details => true)},
        %r{^pwd} => lambda {|m, s| AddRepo.new(m, s, :pwd => true)},
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
    end

    class Session
      attr_accessor :repo_name, :username, :continuous
      attr_writer :tracker, :hooks

      def initialize
        setup_singleton_methods
      end

      def tracker
        @tracker ||= {}
      end

      def hooks
        @hooks ||= {}
      end

      def cleanup
        reset_username
        reset_repo_name
      end

      private
      def reset_username
        self.username = CONFIG[:username]
      end

      def reset_repo_name
        self.repo_name = ""
      end

      def setup_singleton_methods
        tracker.singleton_class.class_eval do
          def add_or_replace! repo_name, new_sha=nil
            if Hash === repo_name
              merge! repo_name
              return true
            else
              if keys.include? repo_name and self[repo_name] == new_sha
                return
              elsif keys.include? repo_name
                ret = {:replace => true}
              else
                ret = {:add => true}
              end
            end
            merge! repo_name => new_sha
            ret
          end
        end
      end
    end # end of Session class

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
        @session.cleanup
      end
    end

    # The track method closes over a list variable to store recent info on
    # tracked repositories.
    # Options: :sha, :latest, :full, :list (all boolean).
    # The :list => true option gives back the commit object from the list.

    list = []

    define_method :track do |repo, options={}|
      if repo.include? '/'
        username, repo_name = repo.split '/'
        full_repo_name = repo
      else
        username, repo_name = @session.username, repo
        full_repo_name = "#{username}/#{repo_name}"
      end
      unless options[:list]
        hist = nil
        begin
          open "https://api.github.com/repos/#{username}/" \
          "#{repo_name}/commits" do |f|
            hist = JSON.parse f.read
          end
        rescue
          @socket.puts "Not a Github repository name"
          throw(:invalid_input)
        end
        new_info =
          {full_repo_name =>
            {'sha' => hist.first['sha'],
             'commit' =>
               {'message' => hist.first['commit']['message'],
                'committer' => {'name' => hist.first['commit']['committer']['name']}
               }
            }
          }
        commit = Commit.new(new_info)
        # update the list
        list.reject! {|cmt| cmt.repo == full_repo_name}
        list << commit
      end
      if options[:full]
        # unsupported so far
        raise ArgumentError.new
      elsif options[:latest]
        commit.dup
      elsif options[:list]
        list.each {|c| return c if c.repo == full_repo_name}
        nil
      else
        # default
        Commit.new full_repo_name => {'sha' => hist.first['sha']}
      end
    end

    private
    def listen(port)
      @server = TCPServer.open(port)
    end

    def setup_env(options={})
      @daemonized = options[:daemon]
      @sockets = [@server]  # An array of sockets we'll monitor
      ['INT', 'KILL'].each do |sig|
        trap(sig) do
          @sockets.each {|s| s.close}
          STDOUT.puts
          exit 1
        end
      end
      @session = Session.new
      unless CONFIG[:default_track].nil?
        CONFIG[:default_track].each do |repo|
          commit = track(repo)
          @session.tracker.merge! commit.repo => commit.sha
        end
      end
      unless CONFIG[:load_hooks].empty?
        hooks = CONFIG[:load_hooks].dup
        session_load :hooks => hooks
      end
      unless CONFIG[:load_repos].empty?
        repos = CONFIG[:load_repos].dup
        session_load :repos => repos
      end
      @session.username = CONFIG[:username]
      @remote_connection = false
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
      # if no client is connected, but the commits array contains repos
      if @sockets.size == 1 and !@session.tracker.empty?

        loop do
          sleep_amt = CONFIG[:oncearound] / @session.tracker.length
          @session.tracker.each do |repo,sha|
            start_time = Time.now
            commit = track(repo, :latest => true)
            api_time = (Time.now - start_time).to_i
            if commit.sha == sha
              (sleep_amt - api_time).times do
                sleep 1
                @remote_connection = client_ready(@sockets) ? true : false
                throw(:connect, true) if @remote_connection
              end
            else
              # There was a change to a tracked repository.
              full_repo_name = commit.repo
              commit_msg     = commit.commit_message
              committer      = commit.committer_name
              new_sha        = commit.sha
              change_msg = "Repo #{full_repo_name} has changed\nNew commit: " \
                "#{commit_msg}\n=> #{committer}"
              case CONFIG[:desktop_notification]
              when "libnotify"
                Notification::GnomeNotify.notify("Hubeye", change_msg)
                Logger.log_change(full_repo_name, commit_msg, committer)
              when "growl"
                Autotest::Growl.growl("Hubeye", change_msg)
                Logger.log_change(full_repo_name, commit_msg, committer)
              when nil
                if @daemonized
                  Logger.log_change(full_repo_name, commit_msg, committer)
                else
                  Logger.log_change(full_repo_name, commit_msg, committer, :include_terminal => true)
                end
              end
              # execute any hooks for that repository
              unless @session.hooks.nil? || @session.hooks.empty?
                if hooks = @session.hooks[full_repo_name]
                  hooks.each do |dir,cmds|
                    # execute() takes [commands], {options} where
                    # options = :directory and :repo
                    Hooks::Command.execute(cmds, :directory => dir, :repo => full_repo_name)
                  end
                end
              end
              @session.tracker.add_or_replace!(full_repo_name, new_sha)
            end
          end
        end # end of (while remote_connection == false)
      else
        @remote_connection = client_ready(@sockets, :block => true) ? true : false
        throw(:connect, true) if @remote_connection
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
        if socket == @server
          @socket = @server.accept
          sockets << @socket
          # Inform the client of connection
          basic_inform = "Hubeye running on #{Socket.gethostname} as #{@session.username}"
          if !@session.tracker.empty?
            @socket.puts "#{basic_inform}\nTracking: #{@session.tracker.keys.join ', '}"
          else
            @socket.puts basic_inform
          end
          if !@daemonized
            puts "Client connected at #{NOW}"
          end
          @socket.flush
          # And log the fact that the client connected
          # if the client quit, do not wipe the log file
          if @session.continuous
            Logger.log "Accepted connection from #{@socket.peeraddr[2]} (#{NOW})"
          else
            # wipe the log file and start anew
            Logger.relog "Accepted connection from #{@socket.peeraddr[2]} (#{NOW})"
          end
          Logger.log "local:  #{@socket.addr}"
          Logger.log "peer :  #{@socket.peeraddr}"
        end
      end
    end

  end # of Server module

  class HubeyeServer
    include Server

    def initialize(debug=true)
      @debug = debug
    end

  end
end

