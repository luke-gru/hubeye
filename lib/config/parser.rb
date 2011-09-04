class Hubeye
  module Config
    class Parser

      class ConfigParseError < StandardError; end
      attr_reader :username, :load_repos, :oncearound, :load_hooks, :notification_wanted,
                  :default_track

      def initialize(config_file, options={})
        opts = {:test => false}.merge options
        if opts[:test] then klass = StringIO else klass = File end

        # not a pretty line, but take options array from element 1,
        # stringify it, get rid of commas separating the repos and
        # split them back into an array on the spaces
        get_comma_separated_values = Proc.new do
          options[1..-1].join('').gsub(',', '').split(' ')
        end

        klass.open(config_file) do |f|
          while line = f.gets
            line.strip!
            next if line.empty?
            options = line.split(':')
            options.each {|o| o.strip! }
            case options[0]
            when "username"
              @username = options[1]
            when "track"
              @default_track = get_comma_separated_values.call
            when "load repos"
              @load_repos = get_comma_separated_values.call
            when "oncearound"
              @oncearound = options[1].to_i
              if @oncearound.zero?
                raise ConfigParseError.new "oncearound in hubeyerc is " +
                  "#{options[1]} but must be a number that is greater than 0"
              end
            when "load hooks"
              @load_hooks = get_comma_separated_values.call
            when "desktop notification"
              on_off = options[1]
              @notification_wanted = case on_off
              when "off"
                false
              when "on"
                true
              else
                raise ConfigParseError.new "desktop notification in hubeyerc is " +
                  "'#{on_off}' and is expected to be either on or off"
              end
            end
          end
        end
        yield self
      end

    end
  end
end
