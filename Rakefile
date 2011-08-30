task :install => :chmod do
  puts "Done"
end

task :chmod => :makelog do
  binfile = File.join(File.dirname(__FILE__), "/bin/hubeye")
  chmod 0777, binfile unless File.executable?(binfile)
end

task :makelog => :config_file do
  hublog_dir  =  ENV['HOME'] + "/hublog"
  mkdir(hublog_dir) unless File.exists?(hublog_dir)

  hooks_dir = hublog_dir + "/hooks"
  mkdir(hooks_dir) unless File.exists?(hooks_dir)

  repos_dir = hublog_dir + "/repos"
  mkdir(repos_dir) unless File.exists?(repos_dir)

  hublog_file =  File.join(ENV['HOME'], "/hublog/hublog")
  touch hublog_file unless File.exists?(hublog_file)
end

task :config_file do
  config_file = File.join(ENV['HOME'], ".hubeyerc")
  touch config_file unless File.exists? config_file
end

task :config_file => :message

task :message do
  puts "Installing Hubeye..."
end

