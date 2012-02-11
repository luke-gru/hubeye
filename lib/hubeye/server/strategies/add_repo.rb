require 'set'

module Hubeye
  module Server
    module Strategies

      class AddRepo
        STATES = [:added, :replaced, :unchanged, :invalid].freeze
        ADDED = "%{committer} => %{message}\n".freeze
        REPLACED = "New commit on %s\n".freeze
        UNCHANGED = "Repository %s hasn't changed\n".freeze
        INVALID  = "%s isn't a valid Github repository\n".freeze

        # Add the given space-separated Github repo(s) if they're valid
        def call
          repo_names_given = input.split
          @multiple_repos_given = repo_names_given.size > 1
          @unique_repo_names = Set.new
          # hash of states associated with repository names.
          # Ex: {:added => ['luke-gru/hubeye'], :replaced => ['rails/rails'], ...}
          @states_with_repos = Hash[STATES.map {|s| [ s, [] ]}]
          repo_names_given.each do |name|
            full_name = server.full_repo_name(name)
            @unique_repo_names << full_name
          end
          add_repos
          @output = ''; gather_output
          socket.deliver @output
        end

        private

        def add_repos
          @unique_repo_names.each do |full_name|
            change_state = (tracker << full_name).keys.first
            @states_with_repos[change_state] << full_name
          end
        end

        def gather_output
          STATES.each do |state|
            @states_with_repos[state].each do |full_name|
              @output << header(full_name) if @multiple_repos_given
              case state
              when :added
                cmt = tracker.commit(full_name)
                @output << ADDED % {:committer => cmt.committer_name, :message =>  cmt.message}
              when :replaced
                cmt = tracker.commit(full_name)
                @output << REPLACED % full_name
                log_change(full_name, cmt)
              else
                @output << self.class.const_get(state.to_s.upcase) % full_name
              end
              @output << "\n" if @multiple_repos_given && full_name != last_repo_outputted
            end
          end
        end

        def header(full_name)
          ''.tap do |output|
            output << full_name + "\n"
            output << ('=' * full_name.length) + ("\n" * 2)
          end
        end

        def log_change(repo_name, cmt)
          if server.daemonized
            Logger.log_change("#{repo_name}", cmt.message, cmt.committer_name)
          else
            Logger.log_change("#{repo_name}", cmt.message, cmt.committer_name,
                              :include_terminal => true)
          end
        end

        def last_repo_outputted
          return @last if @last
          STATES.reverse_each do |state|
            repo_names = @states_with_repos[state]
            next if repo_names.last.nil?
            return (@last = repo_names.last)
          end
        end
      end # end of AddRepo

    end
  end
end
