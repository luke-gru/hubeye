#!/usr/bin/env ruby
require 'socket'
require 'readline'
require_relative "connection"

module Hubeye
  module Client
    class Client
      attr_accessor :sleep_time

      begin
        Readline.emacs_editing_mode
      rescue NotImplementedError
        @@libedit = true
      ensure
        LIST = %w{quit shutdown exit tracking hook add dir}
        comp_proc = Proc.new {|s| LIST.grep /#{Regexp.escape(s)}/}
        Readline.completion_proc = comp_proc rescue nil
      end

      def initialize(debug=false)
        @debug = debug
        @sleep_time = 0.5
      end

      def start(host, port)
        conn = Connection.new(host, port)
        conn.receive_welcome
        @s = conn.s
        interact
      end

      def get_input_readline(socket)
        @input = Readline.readline('> ', true)
        Readline::HISTORY.push(@input)
      end

      # Now begin a loop of client/server interaction.
      def interact
        while @s
          loop do
            get_input_readline(@s)
            begin
              if @input.match(/^\.$/) # '.' = pwd (of client process)
                @s.puts @input.gsub(/\A\.\Z/, File.split(File.expand_path('.')).last)
              else
                @s.puts @input.gsub(/\//, 'diiv')
              end
            rescue
              # Errno::EPIPE for broken pipes in Unix (server got an ^C or
              # something like that)
              exit 1
            end
            @s.flush
            if @input =~ /load repo/
              puts "Loading..."
            end
            sleep sleep_time
            begin
              response = @s.readpartial(4096)
            rescue EOFError
              response = "Bye!\n"
            end
            if response.chop.strip == "Bye!"
              response[-1] == "\n" ? print(response) : puts(response)
              @s.close
              exit 0
            elsif response.chop.strip.match(/shutting/i)
              @s.close
              exit 0
            else
              response[-1] == "\n" ? print(response) : puts(response)
              next
            end
          end
        end
      end

    end
  end
end
