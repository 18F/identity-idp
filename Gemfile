source 'https://rubygems.org'
git_source(:github) { |repo_name| "https://github.com/#{repo_name}.git" }

ruby "~> #{File.read(File.join(__dir__, '.ruby-version')).strip}"

gem 'rails', '~> 7.1.0'

gem 'activerecord-postgis-adapter', '~> 9.0'
gem 'ahoy_matey', '~> 3.0'
gem 'aws-sdk-kms', '~> 1.4'
gem 'aws-sdk-cloudwatchlogs', require: false
gem 'aws-sdk-pinpoint'
gem 'aws-sdk-pinpointsmsvoice'
gem 'aws-sdk-ses', '~> 1.6'
gem 'aws-sdk-sns'
gem 'aws-sdk-sqs'
gem 'barby', '~> 0.6.8'
gem 'base32-crockford'
gem 'bootsnap', '~> 1.0', require: false
gem 'browser'
gem 'caxlsx', require: false
gem 'concurrent-ruby'
gem 'connection_pool'
gem 'cssbundling-rails'
gem 'devise', '~> 4.8'
gem 'dotiw', '>= 4.0.1'
gem 'faraday', '~> 2'
gem 'faker'
gem 'faraday-retry'
gem 'foundation_emails'
gem 'good_job', '~> 3.0'
gem 'hashie', '~> 4.1'
gem 'http_accept_language'
gem 'identity-hostdata', github: '18F/identity-hostdata', tag: 'v3.4.2'
gem 'identity-logging', github: '18F/identity-logging', tag: 'v0.1.0'
gem 'identity_validations', github: '18F/identity-validations', tag: 'v0.7.2'
gem 'jsbundling-rails', '~> 1.1.2'
gem 'jwe'
gem 'jwt'
gem 'lograge', '>= 0.11.2'
gem 'lookbook', '~> 2.0.0', require: false
gem 'lru_redux'
gem 'mail'
gem 'msgpack', '~> 1.6'
gem 'maxminddb'
gem 'multiset'
gem 'net-sftp'
gem 'newrelic_rpm', '~> 9.0'
gem 'puma', '~> 5.6.7'
gem 'pg'
gem 'phonelib'
gem 'premailer-rails', '>= 1.12.0'
gem 'profanity_filter'
gem 'propshaft'
gem 'rack', '>= 2.2.3.1'
gem 'rack-attack', '>= 6.2.1'
gem 'rack-cors', '>= 1.0.5', require: 'rack/cors'
gem 'rack-headers_filter'
gem 'rack-timeout', require: false
gem 'redacted_struct'
gem 'redis', '>= 3.2.0'
gem 'redis-session-store', github: '18F/redis-session-store', tag: 'v1.0.1-18f'
gem 'retries'
gem 'rotp', '~> 6.1'
gem 'rqrcode'
gem 'ruby-progressbar'
gem 'ruby-saml'
gem 'safe_target_blank', '>= 1.0.2'
gem 'saml_idp', github: '18F/saml_idp', tag: '0.18.2-18f'
gem 'scrypt'
gem 'simple_form', '>= 5.0.2'
gem 'stringex', require: false
gem 'strong_migrations', '>= 0.4.2'
gem 'subprocess', require: false
gem 'terminal-table', require: false
gem 'valid_email', '>= 0.1.3'
gem 'view_component', '~> 3.0.0'
gem 'webauthn', '~> 2.5.2'
gem 'xmldsig', '~> 0.6'
gem 'xmlenc', '~> 0.7', '>= 0.7.1'
gem 'yard', require: false
gem 'zlib', require: false

# This version of the zxcvbn gem matches the data and behavior of the zxcvbn NPM package.
# It should not be updated without verifying that the behavior still matches JS version 4.4.2.
gem 'zxcvbn', '0.1.9'

group :development do
  gem 'better_errors', '>= 2.5.1'
  gem 'derailed_benchmarks'
  gem 'irb'
  gem 'letter_opener', '~> 1.8'
  gem 'rack-mini-profiler', '>= 1.1.3', require: false
end

group :development, :test do
  gem 'brakeman', require: false
  gem 'bullet', '~> 7.0'
  gem 'capybara-webmock', git: 'https://github.com/hashrocket/capybara-webmock.git', ref: 'd3f3b7c'
  gem 'erb_lint', '~> 0.4.0', require: false
  gem 'i18n-tasks', '~> 1.0'
  gem 'knapsack'
  gem 'listen'
  gem 'nokogiri', '~> 1.14.0'
  gem 'pg_query', require: false
  gem 'pry-byebug'
  gem 'pry-doc'
  gem 'pry-rails'
  gem 'psych'
  gem 'rspec', '~> 3.12.0'
  gem 'rspec-rails', '~> 6.0', '>= 6.0.4'
  gem 'rubocop', '~> 1.55.1', require: false
  gem 'rubocop-performance', '~> 1.19.0', require: false
  gem 'rubocop-rails', '>= 2.5.2', require: false
  gem 'rubocop-rspec', require: false
end

group :test do
  gem 'axe-core-rspec', '~> 4.2'
  gem 'bundler-audit', require: false
  gem 'simplecov', '~> 0.22.0', require: false
  gem 'simplecov-cobertura'
  gem 'simplecov_json_formatter'
  gem 'email_spec'
  gem 'factory_bot_rails', '>= 6.2.0'
  gem 'rack_session_access', '>= 0.2.0'
  gem 'rack-test', '>= 1.1.0'
  gem 'rails-controller-testing', '>= 1.0.4'
  gem 'rspec-retry'
  gem 'rspec_junit_formatter'
  gem 'shoulda-matchers', '~> 4.0', require: false
  gem 'simple_xlsx_reader', require: false
  gem 'tableparser', require: false
  gem 'webmock'
  gem 'zonebie'
end
