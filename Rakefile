task :install => :chmod do
  puts "Done"
end

task :chmod => :config_file do
  binfile = File.join(File.dirname(__FILE__), "/bin/hubeye")
  chmod 0777, binfile unless File.executable?(binfile)
end

task :config_file do
  config_file = File.join(ENV['HOME'], "/.hubeye/hubeyerc")
  touch config_file unless File.exists? config_file
end

task :config_file => :makelog

task :makelog => :message do
  hubeye_dir  =  ENV['HOME'] + "/.hubeye"
  mkdir(hubeye_dir) unless File.exists?(hubeye_dir)

  hooks_dir = hubeye_dir + "/hooks"
  mkdir(hooks_dir) unless File.exists?(hooks_dir)

  repos_dir = hubeye_dir + "/repos"
  mkdir(repos_dir) unless File.exists?(repos_dir)

  hubeye_log_file =  File.join(ENV['HOME'], "/.hubeye/log")
  touch hubeye_log_file unless File.exists?(hubeye_log_file)
end



task :message do
  puts "Installing Hubeye..."
end

