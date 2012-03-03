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
        # lambda {|input| input.something?} => SomeStrategy.new(decision)
        #
        # values: lambda {|decision, matches|  SomeStrategy.new(decision, matches)}
        STRATEGIES = {
          %r{\Ashutdown\Z} => lambda {|d, m| Shutdown.new(d, m)},
          %r{\Aquit|exit\Z} => lambda {|d, m| Exit.new(d, m)},
          %r{\Atracking\s*\Z} => lambda {|d, m| ListTracking.new(d, m)},
          %r{\Atracking\s*-d\Z} => lambda {|d, m| ListTracking.new(d, m, :details => true)},
          %r{\Aadd (.*)} => lambda {|d, m| AddRepo.new(d, m)},
          %r{\A\s*save hook(s?) as (.+)\Z} => lambda {|d, m| SaveHook.new(d, m)},
          %r{\A\s*save repo(s?) as (.+)\Z} => lambda {|d, m| SaveRepo.new(d, m)},
          %r{\A\s*load hook(s?) (.+)\Z} => lambda {|d, m| LoadHook.new(d, m)},
          %r{\A\s*load repo(s?) (.+)\Z} => lambda {|d, m| LoadRepo.new(d, m)},
          %r{\A\s*internal load hook(s?) (.+)\Z} => lambda {|d, m| LoadHook.new(d, m, :internal => true)},
          %r{\A\s*internal load repo(s?) (.+)\Z} => lambda {|d, m| LoadRepo.new(d, m, :internal => true)},
          %r{\Ahook add ([-\w]+/[-\w]+) (dir:\s?(.*))?\s*cmd:\s?(.*)\Z} => lambda {|d, m| AddHook.new(d, m)},
          %r{\Ahook list\Z} => lambda {|d, m| ListHooks.new(d, m)},
          %r{^\s*$} => lambda {|d, m| Next.new(d, m)},
          %r{\Arm\s*-a\Z} => lambda {|d, m| RmRepo.new(d, m, :all => true)},
          %r{\Arm ([-\w]+/?[-\w]*)\Z} => lambda {|d, m| RmRepo.new(d, m)},
          # if all else fails, try to add the input as a repo
          %r{\A(.*)} => lambda {|d, m| AddRepo.new(d, m)},
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

        # Get all the strategy classes from the files names in the /server/strategies/
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

        def call_strategy
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
