module Hubeye
  module Server
    module Strategies

      class Next
        def call
          socket.deliver ""
        end
      end

    end
  end
end
