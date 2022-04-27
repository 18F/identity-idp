source 'https://rubygems.org'
git_source(:github) { |repo_name| "https://github.com/#{repo_name}.git" }

ruby "~> #{File.read('.ruby-version').strip}"

gem 'rails', '~> 6.1.4'

gem 'ahoy_matey', '~> 3.0'
gem 'aws-sdk-kms', '~> 1.4'
gem 'aws-sdk-pinpoint'
gem 'aws-sdk-pinpointsmsvoice'
gem 'aws-sdk-ses', '~> 1.6'
gem 'aws-sdk-sns'
gem 'base32-crockford'
gem 'blueprinter', '~> 0.25.3'
gem 'bootsnap', '~> 1.9.0', require: false
gem 'browser'
gem 'connection_pool'
gem 'cssbundling-rails'
gem 'devise', '~> 4.8'
gem 'dotiw', '>= 4.0.1'
gem 'faraday'
gem 'foundation_emails'
gem 'good_job', '~> 2.7.0'
gem 'hashie', '~> 4.1'
gem 'hiredis', '~> 0.6.0'
gem 'http_accept_language'
gem 'identity-hostdata', github: '18F/identity-hostdata', tag: 'v3.4.0'
gem 'identity-logging', github: '18F/identity-logging', tag: 'v0.1.0'
gem 'identity_validations', github: '18F/identity-validations', tag: 'v0.7.2'
gem 'jsbundling-rails', '~> 1.0.0'
gem 'jwt'
gem 'lograge', '>= 0.11.2'
gem 'lru_redux'
gem 'maxminddb'
gem 'multiset'
gem 'net-sftp'
gem 'newrelic_rpm', '~> 8.0'
gem 'pg'
gem 'phonelib'
gem 'premailer-rails', '>= 1.11.1'
gem 'profanity_filter'
gem 'rack-attack', '>= 6.2.1'
gem 'rack-cors', '>= 1.0.5', require: 'rack/cors'
gem 'rack-headers_filter'
gem 'rack-timeout', require: false
gem 'redacted_struct'
gem 'redis', '>= 3.2.0'
gem 'redis-namespace'
gem 'redis-session-store', '>= 0.11.4'
gem 'retries'
gem 'rotp', '~> 6.1'
gem 'rqrcode'
gem 'ruby-progressbar'
gem 'ruby-saml'
gem 'safe_target_blank', '>= 1.0.2'
gem 'saml_idp', github: '18F/saml_idp', tag: '0.16.0-18f'
gem 'scrypt'
gem 'secure_headers', '~> 6.3'
gem 'simple_form', '>= 5.0.2'
gem 'stringex', require: false
gem 'strong_migrations', '>= 0.4.2'
gem 'subprocess', require: false
gem 'uglifier', '~> 4.2'
gem 'valid_email', '>= 0.1.3'
gem 'view_component', '~> 2.51.0'
gem 'webauthn', '~> 2.1'
gem 'xmldsig', '~> 0.6'
gem 'xmlenc', '~> 0.7', '>= 0.7.1'
gem 'yard'

# This version of the zxcvbn gem matches the data and behavior of the zxcvbn NPM package.
# It should not be updated without verifying that the behavior still matches JS version 4.4.2.
gem 'zxcvbn', '0.1.7'

group :development do
  gem 'better_errors', '>= 2.5.1'
  gem 'binding_of_caller'
  gem 'derailed_benchmarks', '~> 1.8'
  gem 'guard-rspec', require: false
  gem 'irb'
  gem 'octokit'
  gem 'rack-mini-profiler', '>= 1.1.3', require: false
  gem 'rails-erd', '>= 1.6.0'
end

group :development, :test do
  gem 'aws-sdk-cloudwatchlogs', require: false
  gem 'brakeman', require: false
  gem 'bullet', '>= 6.0.2'
  gem 'data_uri', require: false
  gem 'erb_lint', '~> 0.1.0', require: false
  gem 'i18n-tasks', '>= 0.9.31'
  gem 'knapsack'
  gem 'nokogiri', '~> 1.13.4'
  gem 'parallel_tests'
  gem 'pg_query', require: false
  gem 'pry-byebug'
  gem 'pry-doc'
  gem 'pry-rails'
  gem 'psych'
  gem 'puma'
  gem 'rspec-rails', '~> 4.0'
  gem 'rubocop', '~> 1.23.0', require: false
  gem 'rubocop-performance', '~> 1.12.0', require: false
  gem 'rubocop-rails', '>= 2.5.2', require: false
end

group :test do
  gem 'axe-core-rspec', '~> 4.2'
  gem 'bundler-audit', require: false
  gem 'capybara-selenium', '>= 0.0.6'
  gem 'simplecov', '~> 0.21.0', require: false
  gem 'simplecov-cobertura'
  gem 'simplecov_json_formatter'
  gem 'email_spec'
  gem 'factory_bot_rails', '>= 5.2.0'
  gem 'faker'
  gem 'rack_session_access', '>= 0.2.0'
  gem 'rack-test', '>= 1.1.0'
  gem 'rails-controller-testing', '>= 1.0.4'
  gem 'rspec-retry'
  gem 'shoulda-matchers', '~> 4.0', require: false
  gem 'webdrivers', '~> 4.0'
  gem 'webmock'
  gem 'zonebie'
end
