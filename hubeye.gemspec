# require_relative doesn't work for gemspecs
require File.join(File.dirname(__FILE__), 'VERSION')

require 'rake'

summary = 'Github repository commit watcher -- keep your eye on new commits ' +
          'from multiple repos through an interactive CLI'
files = FileList['lib/**/*.rb', 'bin/*', '[A-Z]*', 'test/**/*', 'images/*', 'tasks/*'].to_a

Gem::Specification.new do |s|
  s.name = 'hubeye'
  s.version = Hubeye::VERSION * '.'
  s.date = Time.now.to_s[0...10]
  s.authors = ['Luke Gruber']
  s.email = 'luke.gru@gmail.com'
  s.summary = summary
  s.description = summary
  s.bindir  = 'bin'
  s.files = files
  s.add_dependency('octopi')
  s.executables << 'hubeye'
  s.license = 'MIT'
  s.required_ruby_version = '>= 1.8.7'
end
