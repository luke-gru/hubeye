module Hubeye
  module Helpers
    module Time
      NOW = lambda { ::Time.now.strftime("%m/%d/%Y at %I:%M%p") }
    end
  end
end

