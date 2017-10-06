# if we're on a server, always default to production
if File.exist?('/etc/login.gov/info/domain')
  ENV['RAILS_ENV'] ||= 'production'.freeze
end

ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)

require 'bundler/setup' # Set up gems listed in the Gemfile.
