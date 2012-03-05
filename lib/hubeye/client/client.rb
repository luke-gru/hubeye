#!/usr/bin/env ruby
require File.expand_path('../connection', __FILE__)
require 'readline'

module Hubeye
  module Client
    class Client

      def self.testing?
        ENV["HUBEYE_ENV"] == 'test'
      end

      @@stty_save = `stty -g` unless testing?

      begin
        Readline.emacs_editing_mode
      rescue NotImplementedError
        @@libedit = true
      ensure
        LIST = %w{quit shutdown exit tracking hook add dir}
        comp_proc = Proc.new {|s| LIST.grep /^#{Regexp.escape(s)}/}
        Readline.completion_proc = comp_proc rescue nil
      end

      def initialize(debug=false)
        @debug = debug
      end


      def start(host, port)
        conn = Connection.new(host, port)
        conn.receive_welcome
        @s = conn.s
        interact
      end

      private
      def interact
        loop do
          get_input_from_readline
          begin
            if @input.match(/^(add)?\s*\.$/) # '.' = pwd (of client process)
              @input.gsub!(/\./, File.split(File.expand_path('.')).last)
            else
              @input.gsub!(/\//, 'diiv')
            end
            @s.deliver @input
          rescue => e
            # Errno::EPIPE for broken pipes in Unix (server got an ^C or
            # something like that)
            puts e.message
            puts e.backtrace
            exit 1
          end
          if @input =~ /load repo/
            puts "Loading..."
          end
          begin
            mesg = @s.read_all
          rescue EOFError
            mesg = "Bye!"
          end
          if mesg.strip == "Bye!"
            puts(mesg)
            @s.close
            exit 0
          elsif mesg.strip.match(/shutting/i)
            @s.close
            exit 0
          else
            puts(mesg)
            next
          end
        end
      end

      def get_input_from_readline
        begin
          @input = Readline.readline('> ', true)
        rescue Interrupt => e
          system('stty', @@stty_save) unless Client.testing?
          exit
        end
      end
    end
  end
end
