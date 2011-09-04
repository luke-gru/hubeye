class Hubeye
  module Config
    class Parser
      attr_reader :username, :track, :oncearound, :hooks

      def initialize(config_file, options={})
        opts = {:test => false}.merge options
        if opts[:test] then klass = StringIO else klass = File end

        # not a pretty line, but take options array from element 1,
        # stringify it, get rid of commas separating the repos and
        # split them back into an array on the spaces
        get_separated_comma_values = Proc.new do
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
              @track = get_separated_comma_values.call
            when "oncearound"
              @oncearound = options[1].to_i
            when "hooks"
              @hooks = get_separated_comma_values.call
            end
          end
        end
        yield self
      end

    end
  end
end
