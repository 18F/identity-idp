source 'https://rubygems.org'
git_source(:github) { |repo_name| "https://github.com/#{repo_name}.git" }

ruby '~> 2.6.5'

gem 'rails', '~> 5.2.4', '>= 5.2.4.3'

gem 'ahoy_matey', '~> 2.2', '>= 2.2.1'
gem 'american_date'
gem 'aws-sdk-kms', '~> 1.4'
gem 'aws-sdk-ses', '~> 1.6'
gem 'base32-crockford'
gem 'device_detector'
gem 'devise', '~> 4.7.1'
gem 'dotiw', '>= 4.0.1'
gem 'exception_notification', '>= 4.4.0'
gem 'faraday'
gem 'figaro'
gem 'foundation_emails'
gem 'gibberish'
gem 'hiredis'
gem 'http_accept_language'
gem 'identity-hostdata', github: '18F/identity-hostdata', tag: 'v0.4.1'
gem 'identity-telephony', github: '18f/identity-telephony', tag: 'v0.1.5'
gem 'identity_validations', github: '18F/identity-validations', branch: 'master'
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
gem 'proofer', github: '18F/identity-proofer-gem', tag: 'v2.7.0'
gem 'pry-doc'
gem 'pry-rails'
gem 'rack-attack', '>= 6.2.1'
gem 'rack-cors', '>= 1.0.5', require: 'rack/cors'
gem 'rack-headers_filter'
gem 'rack-timeout'
gem 'raise-if-root'
gem 'readthis'
gem 'recaptcha', require: 'recaptcha/rails'
gem 'redis-session-store', '>= 0.11.3'
gem 'rotp', '~> 3.3.1'
gem 'rqrcode'
gem 'ruby-progressbar'
gem 'ruby-saml'
gem 'safe_target_blank', '>= 1.0.2'
gem 'saml_idp', git: 'https://github.com/18F/saml_idp.git', tag: '0.10.0.pre.18f'
gem 'sassc-rails', '~> 2.1.2'
gem 'scrypt'
gem 'secure_headers', '~> 6.3'
gem 'simple_form', '>= 5.0.2'
gem 'sinatra', '>= 2.0.7', require: false
gem 'slim-rails', '>= 3.2.0'
gem 'stringex', require: false
gem 'strong_migrations', '>= 0.4.2'
gem 'subprocess', require: false
gem 'twilio-ruby'
gem 'two_factor_authentication', '>= 2.1.1'
gem 'uglifier', '~> 3.2'
gem 'user_agent_parser'
gem 'valid_email', '>= 0.1.3'
gem 'webauthn', '~> 2.1.0'
gem 'webpacker', '~> 3.6', '>= 3.6.0'
gem 'xmlenc', '~> 0.7', '>= 0.7.1'
gem 'zxcvbn-js'

group :development do
  gem 'better_errors', '>= 2.5.1'
  gem 'binding_of_caller'
  gem 'brakeman', require: false
  gem 'bummr', require: false
  gem 'derailed', '>= 0.1.0'
  gem 'fasterer', require: false
  gem 'guard-rspec', require: false
  gem 'irb'
  gem 'octokit'
  gem 'overcommit', require: false
  gem 'rack-mini-profiler', '>= 1.1.3', require: false
  gem 'rails-erd', '>= 1.6.0'
end

group :development, :test do
  gem 'bootsnap', '~> 1.4.7', require: false
  gem 'bullet', '>= 6.0.2'
  gem 'i18n-tasks', '>= 0.9.31'
  gem 'knapsack'
  gem 'parallel_tests'
  gem 'pry-byebug'
  gem 'psych'
  gem 'puma'
  gem 'rspec-rails', '~> 3.9', '>= 3.9.1'
  gem 'rubocop', '~> 0.72.0', require: false
  gem 'rubocop-rails', '>= 2.5.2', require: false
  gem 'slim_lint'
end

group :test do
  gem 'axe-matchers', '~> 2.6.0'
  gem 'capybara-screenshot', '>= 1.0.23'
  gem 'capybara-selenium', '>= 0.0.6'
  gem 'codeclimate-test-reporter', require: false
  gem 'database_cleaner'
  gem 'email_spec'
  gem 'factory_bot_rails', '>= 5.2.0'
  gem 'faker'
  gem 'gmail'
  gem 'rack-test', '>= 1.1.0'
  gem 'rack_session_access', '>= 0.2.0'
  gem 'rails-controller-testing', '>= 1.0.4'
  gem 'shoulda-matchers', '~> 4.0.1', require: false
  gem 'timecop'
  gem 'webdrivers', '~> 3.0'
  gem 'webmock'
  gem 'zonebie'
end

group :production do
  gem 'aamva', github: '18F/identity-aamva-api-client-gem', tag: 'v3.4.1'
  gem 'lexisnexis', github: '18F/identity-lexisnexis-api-client-gem', tag: 'v2.1.0'
end
