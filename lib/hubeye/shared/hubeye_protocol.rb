require 'socket'

module HubeyeProtocol
  HEADER_BYTE_SIZE = 4

  def deliver(body)
    header = header(body)
    mesg = header + body
    self.print mesg
    self.flush
  end

  def header(body)
    body_size = body.bytesize
    [body_size].pack("N")
  end

  def read_all
    read_header
    read(@body_size)
  end

  def read_header
    begin
      @body_size = read(HEADER_BYTE_SIZE).unpack("N").first.to_i
    rescue => e
      STDOUT.puts e.message
      STDOUT.puts e.backtrace
      exit 1
    end
  end
end

class TCPSocket
  include HubeyeProtocol
end
