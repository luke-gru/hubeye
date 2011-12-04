class Logger
  LOG_DIR = File.join(ENV['HOME'], '.hubeye', 'log')

  def self.log(msg)
    File.open(LOG_DIR, "a") do |f|
      f.puts(msg)
    end
  end

  def self.relog(msg)
    #wipe the file and start anew
    File.open(LOG_DIR, "w") do |f|
      f.puts(msg)
    end
  end

  # If {include_terminal: true}, log to the terminal too (make sure that the
  # process is not daemonized). Always log to the logfile.

  def self.log_change(repo_name, commit_msg, committer, options={})
    opts = {:include_terminal => false}.merge options
    change_msg = <<-MSG
    ===============================
    Repository: #{repo_name.downcase.strip} has changed (#{Time.now.strftime("%m/%d/%Y at %I:%M%p")})
    Commit msg: #{commit_msg}
    Committer : #{committer}
    ===============================
    MSG
    if opts[:include_terminal]
      STDOUT.puts change_msg
    end
    log(change_msg)
  end

end
