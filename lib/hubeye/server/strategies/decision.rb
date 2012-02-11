require 'forwardable'

$decision_relatives = Dir.glob( File.join(File.expand_path("../", __FILE__), '*') )
$decision_relatives.each {|file| require file }

module Hubeye
  module Server
    module Strategies

        # STRATEGIES hash
        # ===============
        # keys: input matches
        # OR
        # lambda {|input| input.something?} => SomeStrategy.new(basestrategy)
        #
        # values: lambda {|basestrategy, matches| SomeStrategy.new(basestrategy, matches)}
        STRATEGIES = {
          %r{\Ashutdown\Z} => lambda {|s, m| Shutdown.new(s, m)},
          %r{\Aquit|exit\Z} => lambda {|s, m| Exit.new(s, m)},
          %r{\Atracking\s*\Z} => lambda {|s, m| ListTracking.new(s, m)},
          %r{\Atracking\s*-d\Z} => lambda {|s, m| ListTracking.new(s, m, :details => true)},
          %r{\A\s*save hook(s?) as (.+)\Z} => lambda {|s, m| SaveHook.new(s, m)},
          %r{\A\s*save repo(s?) as (.+)\Z} => lambda {|s, m| SaveRepo.new(s, m)},
          %r{\A\s*load hook(s?) (.+)\Z} => lambda {|s, m| LoadHook.new(s, m)},
          %r{\A\s*load repo(s?) (.+)\Z} => lambda {|s, m| LoadRepo.new(s, m)},
          %r{\A\s*internal load hook(s?) (.+)\Z} => lambda {|s, m| LoadHook.new(s, m, :internal => true)},
          %r{\A\s*internal load repo(s?) (.+)\Z} => lambda {|s, m| LoadRepo.new(s, m, :internal => true)},
          %r{\Ahook add ([-\w]+/[-\w]+) (dir:\s?(.*))?\s*cmd:\s?(.*)\Z} => lambda {|s, m| AddHook.new(s, m)},
          %r{\Ahook list\Z} => lambda {|s, m| ListHooks.new(s, m)},
          %r{^\s*$} => lambda {|s, m| Next.new(s, m)},
          %r{\Arm all\Z} => lambda {|s, m| RmRepo.new(s, m, :all => true)},
          %r{\Arm ([-\w]+/?[-\w]*)\Z} => lambda {|s, m| RmRepo.new(s, m)},
          lambda {|inp| not inp.nil?} => lambda {|s| AddRepo.new(s)}
        }

      class Decision
        extend Forwardable
        attr_reader :server, :input
        InvalidInput = Class.new(StandardError)

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

        # Get all the strategy classes from the files names in the /server/strategies
        # directory

        @@strategy_classes = []
        relatives = $decision_relatives.dup
        relatives.delete_if {|file| file == __FILE__}

        relatives.each do |file|
          strat = File.basename(file)
          class_name = strat.sub(/\.rb/, '').split('_').map(&:capitalize).join
          @@strategy_classes << class_name
        end

        @@strategy_classes.each do |class_name|
          klass = Hubeye::Server::Strategies.const_get(class_name)
          klass.class_eval do
            extend Forwardable
            attr_reader :server

            def_delegators :@decision, :input
            def_delegators :@server, :tracker, :session, :sockets, :socket

            def initialize decision, matches=nil, options={}
              @decision = decision
              @matches  = matches
              @options  = options
              @server   = @decision.server
              call
            end
          end
        end

        def call
          STRATEGIES.each do |inp,strat|
            if inp.respond_to? :match
              if m = @input.match(inp)
                return strat.call(self, m)
              end
            elsif inp.respond_to? :call
              if inp.call(@input)
                return strat.call(self)
              end
            end
          end
          raise InvalidInput
        end
      end # end of Decision

    end
  end
end
