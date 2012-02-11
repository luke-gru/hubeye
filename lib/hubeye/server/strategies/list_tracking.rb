module Hubeye
  module Server
    module Strategies

      class ListTracking
        def call
          output = ''
          if @options[:details]
            commit_list = tracker.commit_list
            commit_list.each do |cmt|
              output << cmt.repo_name + "\n"
              underline = '=' * cmt.repo_name.length
              output << underline + "\n\n"
              output << (cmt.committer_name + " => ") + (cmt.message + "\n")
              output << "\n" unless cmt.repo_name == commit_list.last.repo_name
            end
          else
            output << tracker.repo_names.join(', ')
          end
          output = "none" if output.empty?
          socket.deliver output
        end
      end

    end
  end
end
