require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new

desc 'Run the specs.'
task default: :spec

task :notes do
   system "grep -n -r 'FIXME\\|TODO' lib spec"
end

