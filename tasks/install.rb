HUBEYE_ROOT_DIR  = File.join(ENV['HOME'], '.hubeye')
hubeye_repos_dir = File.join(HUBEYE_ROOT_DIR, 'repos')
hubeye_hooks_dir = File.join(HUBEYE_ROOT_DIR, 'hooks')
hubeye_log_file  = File.join(HUBEYE_ROOT_DIR, 'log')
hubeye_conf_file = File.join(HUBEYE_ROOT_DIR, 'hubeyerc')

task :install => :create_config_file do
  puts "Done"
end

task :create_config_file do
  touch hubeye_conf_file unless File.exists? hubeye_conf_file
end

task :create_config_file => :make_log

task :make_log => :message do
  mkdir HUBEYE_ROOT_DIR  unless File.exists? HUBEYE_ROOT_DIR
  mkdir hubeye_hooks_dir unless File.exists? hubeye_hooks_dir
  mkdir hubeye_repos_dir unless File.exists? hubeye_repos_dir

  touch hubeye_log_file unless File.exists?  hubeye_log_file
end

task :message do
  puts "Installing hubeye..."
end
