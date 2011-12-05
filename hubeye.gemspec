require File.join(File.dirname(__FILE__), 'VERSION')
require 'rake'

summary = <<SUMMARY
Github repository commit watcher -- keep your eye on new commits
from multiple repos through an interactive CLI.
SUMMARY

description = <<DESC
Keep your eye on new commits being pushed to Github through an
interactive interface. When new commits are seen by Hubeye, you can
choose to be notified by one of Hubeye's notification systems (growl,
libnotify, etc...). All interesting activity is logged, so leave
your computer, come back, and know what changed.
DESC

files = FileList['lib/**/*.rb', 'bin/*', '[A-Z]*', 'test/**/*', 'images/*', 'tasks/*'].to_a

Gem::Specification.new do |s|
  s.name = 'hubeye'
  s.version = Hubeye::VERSION * '.'
  s.date = Time.now.to_s[0...10]
  s.authors = ['Luke Gruber']
  s.email = 'luke.gru@gmail.com'
  s.summary = summary
  s.description = description
  s.bindir  = 'bin'
  s.files = files
  s.executables << 'hubeye'
  s.license = 'MIT'
  s.required_ruby_version = '>= 1.8.7'
end
