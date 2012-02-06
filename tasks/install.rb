HUBEYE_ROOT_DIR  = File.join(ENV['HOME'], '.hubeye')
HUBEYE_REPOS_DIR = File.join(HUBEYE_ROOT_DIR, 'repos')
HUBEYE_HOOKS_DIR = File.join(HUBEYE_ROOT_DIR, 'hooks')
HUBEYE_LOG_FILE  = File.join(HUBEYE_ROOT_DIR, 'log')
HUBEYE_CONF_FILE = File.join(HUBEYE_ROOT_DIR, 'hubeyerc')

task :install => :create_config_file do
  puts "Done"
end

task :create_config_file do
  touch HUBEYE_CONF_FILE unless File.exists? HUBEYE_CONF_FILE
end

task :create_config_file => :make_log

task :make_log => :message do
  mkdir HUBEYE_ROOT_DIR  unless File.exists? HUBEYE_ROOT_DIR
  mkdir HUBEYE_HOOKS_DIR unless File.exists? HUBEYE_HOOKS_DIR
  mkdir HUBEYE_REPOS_DIR unless File.exists? HUBEYE_REPOS_DIR

  touch HUBEYE_LOG_FILE unless File.exists?  HUBEYE_LOG_FILE
end

task :message do
  puts "Installing hubeye..."
end
