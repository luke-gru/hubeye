class Logger

  def self.log(msg)
    File.open(ENV['HOME'] + "/hublog" * 2, "a") do |f|
      f.puts(msg)
    end
  end

  def self.relog(msg)
    #wipe the file and start anew
    File.open(ENV['HOME'] + "/hublog" * 2, "w") do |f|
      f.puts(msg)
    end
  end

  ##If {include_socket: true} is passed, then log to the client as well. If
  #{include_terminal: true}, log to the terminal too (make sure that the
  #process is not daemonized). Always log to the logfile.

  def self.log_change(repo_name, commit_msg, committer, options={})
    opts = {:include_socket => false, :include_terminal => false}.merge options
    change_msg = <<-MSG
    ===============================
    Repository: #{repo_name.downcase.strip} has changed (#{Time.now.strftime("%m/%d/%Y at %I:%M%p")})
    Commit msg: #{commit_msg}
    Committer : #{committer}
    ===============================
    MSG
    if opts[:include_socket]
      socket.puts(change_msg)
    end

    if opts[:include_terminal]
      puts change_msg
    end
    Logger.log(change_msg)
  end

end
