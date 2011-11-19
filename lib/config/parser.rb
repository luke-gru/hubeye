class Hubeye
  module Config
    class Parser

      class ConfigParseError < StandardError; end
      attr_reader :username, :load_repos, :oncearound, :load_hooks, :notification_wanted,
                  :default_track

      def initialize(config_file, options={})
        opts = {:test => false}.merge options
        if opts[:test] then klass = StringIO else klass = File end
        klass.open(config_file) do |f|
          while line = f.gets
            line = line.strip
            next if line.empty?
            user_opts = line.split(':')
            user_opts.map! {|o| o.strip }
            case user_opts[0]
            when "username"
              @username = user_opts[1]
            when "track"
              @default_track = get_comma_separated_values(user_opts[1])
            when "load repos"
              @load_repos = get_comma_separated_values(user_opts[1])
            when "oncearound"
              @oncearound = user_opts[1].to_i
              if @oncearound.zero?
                raise ConfigParseError.new "oncearound in hubeyerc is " \
                  "#{user_opts[1]} but must be a number that is greater than 0"
              end
            when "load hooks"
              @load_hooks = get_comma_separated_values(user_opts[1])
            when "desktop notification"
              on_off = user_opts[1]
              @notification_wanted = case on_off
              when "off"
                false
              when "on"
                true
              else
                raise ConfigParseError.new "desktop notification in hubeyerc is " \
                  "'#{on_off}' and is expected to be either on or off"
              end
            end
          end
        end
        yield self
      end

      private
      def get_comma_separated_values(values)
        values.split(',').map {|v| v.strip}
      end

    end
  end
end
