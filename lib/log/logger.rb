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

  def self.log_change(repo_name, commit_msg, committer, socket)
    change_msg = <<-MSG
    ===============================
    Repository: #{repo_name.downcase.strip} has changed (#{Time.now.strftime("%m/%d/%Y at %I:%M%p")})
    Commit msg: #{commit_msg}
    Committer : #{committer}
    ===============================
     MSG
     socket.puts(change_msg)
     Logger.log(change_msg)
  end

end
