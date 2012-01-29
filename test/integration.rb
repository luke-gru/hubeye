class HubeyeIntegrationTest < Test::Unit::TestCase
  include Hubeye::Environment

  EXECUTABLE = File.join(BINDIR, 'hubeye')

  def interact
    start_server
    sleep 0.5
    start_client
  end

  def start_server
    system "#{EXECUTABLE} -s"
  end

  def start_client
    IO.popen("#{EXECUTABLE} -c", "r+") do |p|
      p.write 'fjdksfjlsdj'
      p.close_write
      p.read.chomp
    end
  end

end
