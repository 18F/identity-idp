source 'https://rubygems.org'
git_source(:github) { |repo_name| "https://github.com/#{repo_name}.git" }

ruby "~> #{File.read(File.join(__dir__, '.ruby-version')).strip}"

gem 'rails', '~> 8.0.0'

gem 'ahoy_matey', '~> 3.0'
# pod identity requires 3.188.0
# https://docs.aws.amazon.com/eks/latest/userguide/pod-id-minimum-sdk.html
gem 'aws-sdk-core', '>= 3.188.0'
gem 'aws-sdk-kms', '~> 1.4'
gem 'aws-sdk-cloudwatchlogs', require: false
gem 'aws-sdk-pinpoint'
gem 'aws-sdk-pinpointsmsvoice'
gem 'aws-sdk-ses', '~> 1.6'
gem 'aws-sdk-sns'
gem 'aws-sdk-sqs'
gem 'barby', '~> 0.6.8'
gem 'base32-crockford'
gem 'base64'
gem 'bigdecimal'
gem 'bootsnap', '~> 1.0', require: false
gem 'browser'
gem 'caxlsx', require: false
gem 'concurrent-ruby'
gem 'connection_pool'
gem 'csv'
gem 'cssbundling-rails'
gem 'devise', '~> 4.8'
gem 'dotiw', '>= 4.0.1'
gem 'faraday', '~> 2'
gem 'faraday-retry'
gem 'fugit'
gem 'foundation_emails'
gem 'good_job', '~> 4.0'
gem 'http_accept_language'
gem 'identity-hostdata', github: '18F/identity-hostdata', tag: 'v4.4.1'
gem 'identity-logging', github: '18F/identity-logging', tag: 'v0.1.1'
gem 'identity_validations', github: '18F/identity-validations', tag: 'v0.7.2'
gem 'jsbundling-rails', '~> 1.1.2'
gem 'jwe'
gem 'jwt'
gem 'lograge', '>= 0.11.2'
gem 'lookbook', '~> 2.2', require: false
gem 'lru_redux'
gem 'mail'
gem 'msgpack', '~> 1.6'
gem 'maxminddb'
gem 'multiset'
gem 'net-sftp'
gem 'newrelic_rpm', '~> 9.0'
gem 'numbers_and_words', '~> 0.11.12'
gem 'prometheus_exporter'
gem 'puma', '~> 6.0'
gem 'pg'
gem 'phonelib'
gem 'premailer-rails', '>= 1.12.0'
gem 'profanity_filter'
gem 'propshaft'
gem 'rack', '~> 3.0.14'
gem 'rack-attack', github: 'rack/rack-attack', ref: 'd9fedfae4f7f6409f33857763391f4e18a6d7467'
gem 'rack-cors', '> 2.0.1', require: 'rack/cors'
gem 'rack-headers_filter'
gem 'rack-timeout', require: false
gem 'redacted_struct'
gem 'redis', '>= 3.2.0'
gem 'redis-session-store', github: '18F/redis-session-store', tag: 'v1.0.2-18f'
gem 'retries'
gem 'rexml', '~> 3.3'
gem 'rotp', '~> 6.3', '>= 6.3.0'
gem 'rqrcode'
gem 'ruby-progressbar'
gem 'ruby-saml'
gem 'safe_target_blank', '>= 1.0.2'
gem 'saml_idp', github: '18F/saml_idp', tag: '0.23.7-18f'
gem 'scrypt'
gem 'simple_form', '>= 5.0.2'
gem 'stringex', require: false
gem 'strong_migrations', '>= 0.4.2'
gem 'terminal-table', require: false
# until a release includes https://github.com/hallelujah/valid_email/pull/126
gem 'valid_email', '>= 0.1.3', github: 'hallelujah/valid_email', ref: '486b860'
gem 'view_component', '~> 3.0'
gem 'webauthn', '~> 2.5.2'
gem 'xmldsig', '~> 0.6'
gem 'xmlenc', '0.8.0'
gem 'yard', require: false
gem 'zlib', require: false

# This version of the zxcvbn gem matches the data and behavior of the zxcvbn NPM package.
# It should not be updated without verifying that the behavior still matches JS version 4.4.2.
gem 'zxcvbn', '0.1.12'

group :development do
  gem 'better_errors', '>= 2.5.1'
  gem 'derailed_benchmarks'
  gem 'irb'
  gem 'letter_opener', '~> 1.8'
  gem 'rack-mini-profiler', '>= 1.1.3', require: false
end

group :development, :test do
  gem 'brakeman', require: false
  gem 'bullet', '~> 8.0'
  gem 'capybara-webmock', git: 'https://github.com/hashrocket/capybara-webmock.git', ref: 'd3f3b7c'
  gem 'erb_lint', '~> 0.7.0', require: false
  gem 'i18n-tasks', '~> 1.0'
  gem 'knapsack'
  gem 'listen'
  gem 'net-http-persistent', '~> 4.0.2', require: false
  gem 'nokogiri', '~> 1.18.0'
  gem 'pg_query', require: false
  gem 'pry-byebug'
  gem 'pry-rails'
  gem 'psych'
  gem 'rspec', '~> 3.13.0'
  gem 'rspec-rails', '~> 7.0'
  gem 'rubocop', '~> 1.70.0', require: false
  gem 'rubocop-performance', '~> 1.23.0', require: false
  gem 'rubocop-rails', '~> 2.27.0', require: false
  gem 'rubocop-rspec', '~> 3.2.0', require: false
  gem 'rubocop-capybara', require: false
  gem 'sqlite3', require: false
end

group :test do
  gem 'axe-core-rspec', '~> 4.2'
  gem 'bundler-audit', require: false
  gem 'faker'
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
