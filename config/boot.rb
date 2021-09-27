# if we're on a server, always default to production
ENV['RAILS_ENV'] ||= 'production'.freeze if File.exist?('/etc/login.gov/info/domain')

ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)

require 'bundler/setup' # Set up gems listed in the Gemfile.
begin
  require 'bootsnap/setup' if ENV['ENABLE_BOOTSNAP'] != 'false'
rescue LoadError
  # bootsnap is only for dev/test
end
