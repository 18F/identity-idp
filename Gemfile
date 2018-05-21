source 'https://rubygems.org'
git_source(:github) { |repo_name| "https://github.com/#{repo_name}.git" }

ruby '~> 2.3.7'

gem 'rails', '~> 5.1.3'

gem 'ahoy_matey', '~> 2.0'
gem 'american_date'
gem 'aws-sdk-kms', '~> 1.4'
gem 'aws-sdk-ses', '~> 1.6'
gem 'base32-crockford'
gem 'device_detector'
gem 'devise', '~> 4.1'
gem 'dotiw'
gem 'exception_notification'
gem 'figaro'
gem 'foundation_emails'
gem 'gibberish'
gem 'gyoku'
gem 'hashie'
gem 'hiredis'
gem 'http_accept_language'
gem 'httparty'
gem 'identity-hostdata', github: '18F/identity-hostdata', branch: 'master'
gem 'json-jwt'
gem 'lograge'
gem 'net-sftp'
gem 'newrelic_rpm'
gem 'pg'
gem 'phonelib'
gem 'phony_rails'
gem 'premailer-rails'
gem 'proofer', github: '18F/identity-proofer-gem', tag: 'v2.5.0'
gem 'rack-attack'
gem 'rack-cors', require: 'rack/cors'
gem 'rack-headers_filter'
gem 'rack-timeout'
gem 'raise-if-root'
gem 'readthis'
gem 'recaptcha', require: 'recaptcha/rails'
gem 'redis-session-store', github: '18F/redis-session-store', branch: 'master'
gem 'rqrcode'
gem 'ruby-progressbar'
gem 'ruby-saml'
gem 'saml_idp', git: 'https://github.com/18F/saml_idp.git', tag: 'v0.6.0-18f'
gem 'sass-rails', '~> 5.0'
gem 'savon'
gem 'scrypt'
gem 'secure_headers', '~> 3.0'
gem 'sidekiq'
gem 'simple_form'
gem 'sinatra', require: false
gem 'slim-rails'
gem 'stringex', require: false
gem 'strong_migrations'
gem 'twilio-ruby'
gem 'two_factor_authentication'
gem 'typhoeus'
gem 'uglifier', '~> 3.2'
gem 'valid_email'
gem 'webpacker', '~> 3.4'
gem 'whenever', require: false
gem 'xml-simple'
gem 'xmlenc', '~> 0.6'
gem 'zxcvbn-js'

group :development do
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'brakeman', require: false
  gem 'bummr', require: false
  gem 'derailed'
  gem 'fasterer', require: false
  gem 'guard-rspec', require: false
  gem 'overcommit', require: false
  gem 'rack-mini-profiler', require: false
  gem 'rails-erd'
  gem 'reek'
  gem 'rubocop', '~> 0.54.0', require: false
end

group :development, :test do
  gem 'bullet'
  gem 'front_matter_parser'
  gem 'i18n-tasks'
  gem 'knapsack'
  gem 'pry-byebug'
  gem 'rspec-rails', '~> 3.7'
  gem 'slim_lint'
  gem 'thin'
end

group :test do
  gem 'axe-matchers', '~> 1.3.4'
  gem 'capybara-screenshot', github: 'mattheworiordan/capybara-screenshot'
  gem 'capybara-selenium'
  gem 'chromedriver-helper'
  gem 'codeclimate-test-reporter', require: false
  gem 'database_cleaner'
  gem 'email_spec'
  gem 'factory_bot_rails'
  gem 'fakefs', require: 'fakefs/safe'
  gem 'faker'
  gem 'rack-test'
  gem 'rack_session_access'
  gem 'rails-controller-testing'
  gem 'shoulda-matchers', '~> 3.0', require: false
  gem 'timecop'
  gem 'webmock'
  gem 'zonebie'
end

group :production do
  gem 'aamva', git: 'git@github.com:18F/identity-aamva-api-client-gem', tag: 'v3.0.0'
  gem 'equifax', git: 'git@github.com:18F/identity-equifax-api-client-gem.git', tag: 'v1.1.0'
end
