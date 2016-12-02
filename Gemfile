source 'https://rubygems.org'
git_source(:github) { |repo_name| "https://github.com/#{repo_name}.git" }

gem 'rails', '~> 4.2.6'

gem 'ahoy_matey'
gem 'american_date'
gem 'aws-sdk-core'
gem 'browserify-rails'
gem 'devise', '~> 4.1'
gem 'devise_security_extension'
gem 'dotiw'
gem 'figaro'
gem 'foundation_emails'
gem 'gyoku'
gem 'hashie'
gem 'hiredis'
gem 'httparty'
gem 'lograge'
gem 'newrelic_rpm'
gem 'omniauth-saml'
gem 'phony_rails'
gem 'pg'
gem 'premailer-rails'
gem 'proofer', github: '18F/identity-proofer-gem', branch: 'master'
gem 'valid_email'
gem 'rack-attack'
gem 'readthis'
gem 'redis-session-store'
gem 'rqrcode'
gem 'ruby-saml'
gem 'saml_idp', git: 'https://github.com/18F/saml_idp.git', branch: 'master'
gem 'sass-rails', '~> 5.0'
gem 'savon'
gem 'scrypt'
gem 'secure_headers', '~> 3.0'
gem 'sidekiq'
gem 'simple_form'
gem 'sinatra', require: false
gem 'slim-rails'
gem 'split', require: 'split/dashboard'
gem 'twilio-ruby'
gem 'two_factor_authentication', github: 'Houdini/two_factor_authentication', ref: '1d6abe3'
gem 'uglifier', '>= 1.3.0'
gem 'whenever', require: false
gem 'xmlenc', '~> 0.6.4'
gem 'xml-simple'
gem 'zxcvbn-js'

group :deploy do
  gem 'capistrano'
  gem 'capistrano-passenger'
  gem 'capistrano-rails'
  gem 'capistrano-rbenv'
  gem 'capistrano-sidekiq'
end

group :development do
  gem 'better_errors'
  gem 'brakeman', require: false
  gem 'bummr', require: false
  gem 'derailed'
  gem 'binding_of_caller'
  gem 'guard-rspec', require: false
  gem 'overcommit', require: false
  gem 'quiet_assets'
  gem 'rack-mini-profiler', require: false
  gem 'rails-erd'
  gem 'rails_layout'
  gem 'reek'
  gem 'rubocop', require: false
end

group :development, :test do
  gem 'bullet'
  gem 'i18n-tasks'
  gem 'mailcatcher', require: false
  gem 'pry-byebug'
  gem 'rspec-rails', '~> 3.5.2'
  gem 'slim_lint'
  gem 'thin'
end

group :test do
  gem 'capybara-screenshot', github: 'mattheworiordan/capybara-screenshot'
  gem 'axe-matchers'
  gem 'codeclimate-test-reporter', require: false
  gem 'database_cleaner'
  gem 'email_spec'
  gem 'factory_girl_rails'
  gem 'faker'
  gem 'poltergeist'
  gem 'rack_session_access'
  gem 'rack-test'
  gem 'shoulda-matchers', '~> 3.0', require: false
  gem 'test_after_commit'
  gem 'timecop'
  gem 'webmock'
  gem 'zonebie'
end
