source 'https://rubygems.org'
git_source(:github) { |repo_name| "https://github.com/#{repo_name}.git" }

ruby '~> 2.6.5'

gem 'rails', '~> 6.1.3'

# Variables can be overridden for local dev in Gemfile-dev
@doc_auth_gem ||= { github: '18F/identity-doc-auth', tag: 'v0.5.1' }
@hostdata_gem ||= { github: '18F/identity-hostdata', tag: 'v2.0.0' }
@idp_functions_gem ||= { github: '18F/identity-idp-functions', ref:'d9241bdfea85a76c170e456a89' }
@logging_gem ||= { github: '18F/identity-logging', tag: 'v0.1.0' }
@proofer_gem ||= { github: '18F/identity-proofer-gem', ref: 'v2.8.0' }
@telephony_gem ||= { github: '18f/identity-telephony', tag: 'v0.1.12' }
@validations_gem ||= { github: '18F/identity-validations', branch: 'main' }
@saml_gem ||= { github: '18F/saml_idp', tag: 'v0.13.0-18f' }

gem 'identity-doc-auth', @doc_auth_gem
gem 'identity-hostdata', @hostdata_gem
gem 'identity-idp-functions', @idp_functions_gem
gem 'identity-logging', @logging_gem
gem 'proofer', @proofer_gem
gem 'identity-telephony', @telephony_gem
gem 'identity_validations', @validations_gem
gem 'saml_idp', @saml_gem

gem 'ahoy_matey', '~> 3.0'
gem 'american_date'
gem 'autoprefixer-rails', '~> 10.0'
gem 'aws-sdk-cloudwatch'
gem 'aws-sdk-kms', '~> 1.4'
gem 'aws-sdk-lambda'
gem 'aws-sdk-ses', '~> 1.6'
gem 'aws-sdk-sqs'
gem 'base32-crockford'
gem 'daemons', '~> 1.3'
gem 'delayed_job_active_record', '~> 4.1'
gem 'device_detector'
gem 'devise', '~> 4.7.2'
gem 'dotiw', '>= 4.0.1'
gem 'exception_notification', '>= 4.4.0'
gem 'faraday'
gem 'foundation_emails'
gem 'hiredis'
gem 'http_accept_language'
gem 'json-jwt', '>= 1.11.0'
gem 'jwt'
gem 'local_time'
gem 'lograge', '>= 0.11.2'
gem 'maxminddb'
gem 'net-sftp'
gem 'newrelic_rpm'
gem 'pg'
gem 'phonelib'
gem 'premailer-rails', '>= 1.11.1'
gem 'profanity_filter'
gem 'rack-attack', '>= 6.2.1'
gem 'rack-cors', '>= 1.0.5', require: 'rack/cors'
gem 'rack-headers_filter'
gem 'rack-timeout', require: false
gem 'raise-if-root'
gem 'readthis'
gem 'recaptcha', require: 'recaptcha/rails'
gem 'redacted_struct'
gem 'redis-session-store', '>= 0.11.3'
gem 'rotp', '~> 6.1'
gem 'rqrcode'
gem 'ruby-progressbar'
gem 'ruby-saml'
gem 'safe_target_blank', '>= 1.0.2'
gem 'sassc-rails', '~> 2.1.2'
gem 'scrypt'
gem 'secure_headers', '~> 6.3'
gem 'simple_form', '>= 5.0.2'
gem 'stringex', require: false
gem 'strong_migrations', '>= 0.4.2'
gem 'subprocess', require: false
gem 'uglifier', '~> 4.2'
gem 'user_agent_parser'
gem 'valid_email', '>= 0.1.3'
gem 'webauthn', '~> 2.1'
gem 'webpacker', '~> 5.1'
gem 'xmlenc', '~> 0.7', '>= 0.7.1'
gem 'zxcvbn-js'

group :development do
  gem 'better_errors', '>= 2.5.1'
  gem 'binding_of_caller'
  gem 'brakeman', require: false
  gem 'derailed_benchmarks', '~> 1.8'
  gem 'guard-rspec', require: false
  gem 'irb'
  gem 'octokit'
  gem 'rack-mini-profiler', '>= 1.1.3', require: false
  gem 'rails-erd', '>= 1.6.0'
end

group :development, :test do
  gem 'aws-sdk-cloudwatchlogs', require: false
  gem 'bootsnap', '~> 1.5.0', require: false
  gem 'bullet', '>= 6.0.2'
  gem 'erb_lint', '~> 0.0.37', require: false
  gem 'i18n-tasks', '>= 0.9.31'
  gem 'knapsack'
  gem 'nokogiri', '~> 1.11.0'
  gem 'parallel_tests'
  gem 'pry-byebug'
  gem 'pry-doc'
  gem 'pry-rails'
  gem 'psych'
  gem 'puma'
  gem 'rspec-rails', '~> 4.0'
  gem 'rubocop', '~> 1.4.0', require: false
  gem 'rubocop-rails', '>= 2.5.2', require: false
end

group :test do
  gem 'axe-matchers', '~> 2.6.0'
  gem 'capybara-screenshot', '>= 1.0.23'
  gem 'capybara-selenium', '>= 0.0.6'
  gem 'codeclimate-test-reporter', require: false
  gem 'email_spec'
  gem 'factory_bot_rails', '>= 5.2.0'
  gem 'faker'
  gem 'gmail', '>= 0.7.1'
  gem 'rack_session_access', '>= 0.2.0'
  gem 'rack-test', '>= 1.1.0'
  gem 'rails-controller-testing', '>= 1.0.4'
  gem 'rspec-retry'
  gem 'shoulda-matchers', '~> 4.0', require: false
  gem 'timecop'
  gem 'webdrivers', '~> 4.0'
  gem 'webmock'
  gem 'zonebie'
end

group :production do
  @aamva_api_gem ||= { github: '18F/identity-aamva-api-client-gem', tag: 'v4.2.0' }
  @lexisnexis_api_gem ||= { github: '18F/identity-lexisnexis-api-client-gem', tag: 'v3.2.0' }

  gem 'aamva', @aamva_api_gem
  gem 'lexisnexis', @lexisnexis_api_gem
end
