require 'bundler'

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)

require 'coveralls/rake/task'
Coveralls::RakeTask.new
task :spec_with_coveralls => [:spec, 'coveralls:push']