task :install => :chmod do
  puts "Done"
end

task :chmod => :makelog do
  daemon_file =  File.join(File.dirname(__FILE__), "hubeye")
  server_file =  File.join(File.dirname(__FILE__), "hubeye_server.rb")
  client_file =  File.join(File.dirname(__FILE__), "hubeye_client.rb")
  [daemon_file, server_file, client_file].each do |file|
    chmod 0777, file unless File.executable?(file)
  end
end

task :makelog => :config_file do
  hublog_dir  =  ENV['HOME'] + "/hublog"
  mkdir(hublog_dir) unless File.exists?(hublog_dir)
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

