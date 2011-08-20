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

  ##If a socket is passed, then log to the client. If not,
  #log to the terminal (make sure that the process is not
  #daemonized). Always log to the logfile.

  def self.log_change(repo_name, commit_msg, committer, socket=nil)
    change_msg = <<-MSG
    ===============================
    Repository: #{repo_name.downcase.strip} has changed (#{Time.now.strftime("%m/%d/%Y at %I:%M%p")})
    Commit msg: #{commit_msg}
    Committer : #{committer}
    ===============================
    MSG
    if socket
      socket.puts(change_msg)
    else
      puts change_msg
    end
    Logger.log(change_msg)
  end

end
