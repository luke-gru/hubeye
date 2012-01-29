require_relative "test_helper"

class HubeyeIntegrationTest < Test::Unit::TestCase
  include Hubeye::Environment

  EXECUTABLE = File.join(BINDIR, 'hubeye')

  def start_server
    system "#{EXECUTABLE} -s"
  end

  def start_client &blk
    IO.popen("#{EXECUTABLE} -c", "r+") do |c|
      begin
        yield c if c
      ensure
        c.puts "shutdown"
        c.close_write
        c.close
      end
    end
  end

  def setup
    start_server
    sleep 0.5
  end

  def test_truth
    start_client do |c|
      c.puts 'hi'
      @response = c.gets
    end
    STDOUT.puts @response
    assert @response.match /github/i
  end

end
