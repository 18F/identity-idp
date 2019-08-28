source 'https://rubygems.org'
git_source(:github) { |repo_name| "https://github.com/#{repo_name}.git" }

ruby '~> 2.5.3'

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
gem 'greenletters'
gem 'hiredis'
gem 'http_accept_language'
gem 'httparty'
gem 'identity-hostdata', github: '18F/identity-hostdata', branch: 'master'
gem 'identity-telephony', github: '18f/identity-telephony', tag: 'v0.0.7'
gem 'identity_validations', github: '18F/identity-validations', branch: 'master'
gem 'json-jwt'
gem 'local_time'
gem 'lograge'
gem 'maxminddb'
gem 'net-sftp'
gem 'newrelic_rpm'
gem 'pg'
gem 'phonelib'
gem 'pkcs11'
gem 'premailer-rails'
gem 'proofer', github: '18F/identity-proofer-gem', tag: 'v2.7.0'
gem 'pry-doc'
gem 'pry-rails'
gem 'rack-attack'
gem 'rack-cors', require: 'rack/cors'
gem 'rack-headers_filter'
gem 'rack-timeout'
gem 'raise-if-root'
gem 'readthis'
gem 'recaptcha', require: 'recaptcha/rails'
gem 'redis-session-store'
gem 'rotp', '~> 3.3.1'
gem 'rqrcode'
gem 'ruby-progressbar'
gem 'ruby-saml'
gem 'safe_target_blank'
gem 'saml_idp', git: 'https://github.com/18F/saml_idp.git'
gem 'sassc-rails', '~> 2.1.2'
gem 'scrypt'
gem 'secure_headers', '~> 6.0'
gem 'simple_form'
gem 'sinatra', require: false
gem 'slim-rails'
gem 'stringex', require: false
gem 'strong_migrations'
gem 'twilio-ruby'
gem 'two_factor_authentication'
gem 'typhoeus'
gem 'uglifier', '~> 3.2'
gem 'user_agent_parser'
gem 'valid_email'
gem 'webauthn'
gem 'webpacker', '~> 3.4'
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
  gem 'octokit'
  gem 'overcommit', require: false
  gem 'rack-mini-profiler', require: false
  gem 'rails-erd'
  gem 'reek'
  gem 'rubocop', '~> 0.72.0', require: false
  gem 'rubocop-rails', require: false
end

group :development, :test do
  gem 'bullet'
  gem 'i18n-tasks'
  gem 'knapsack'
  gem 'parallel_tests'
  gem 'pry-byebug'
  gem 'psych'
  gem 'puma'
  gem 'rspec-rails', '~> 3.7'
  gem 'slim_lint'
end

group :test do
  gem 'axe-matchers', '~> 1.3.4'
  gem 'capybara-screenshot'
  gem 'capybara-selenium'
  gem 'codeclimate-test-reporter', require: false
  gem 'database_cleaner'
  gem 'email_spec'
  gem 'factory_bot_rails'
  gem 'fakefs', require: 'fakefs/safe'
  gem 'faker'
  gem 'rack-test'
  gem 'rack_session_access'
  gem 'rails-controller-testing'
  gem 'shoulda-matchers', '~> 4.0.1', require: false
  gem 'timecop'
  gem 'webdrivers', '~> 3.0'
  gem 'webmock'
  gem 'zonebie'
end

group :production do
  gem 'aamva', git: 'git@github.com:18F/identity-aamva-api-client-gem', tag: 'v3.2.1'
  gem 'lexisnexis', git: 'git@github.com:18F/identity-lexisnexis-api-client-gem', tag: 'v1.2.0'
end
