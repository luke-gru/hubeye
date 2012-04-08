$:.unshift 'lib'

require 'rake/testtask'
require 'rake/clean'

task :default => [:test]

desc 'Run tests (default)'
Rake::TestTask.new(:test) do |t|
  t.test_files = FileList['test/runner.rb']
end

desc 'Display current version'
task :version do
  require File.expand_path('../version', __FILE__)
  puts Hubeye::VERSION * '.'
end
