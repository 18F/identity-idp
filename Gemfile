source 'https://rubygems.org'

gem 'rails', '~> 4.2.6'

gem 'browserify-rails'
gem 'coffee-rails', '~> 4.1.0'
gem 'devise', '~> 3.5.0'
gem 'dotiw'
gem 'figaro'
gem 'jquery-rails'
gem 'jquery-ui-rails'
gem 'lograge'
gem 'newrelic_rpm'
gem 'omniauth-saml', github: 'amoose/omniauth-saml', branch: 'feature/internal_idp'
gem 'phony_rails', '~> 0.13.1'
gem 'pg'
gem 'pundit'
gem 'valid_email'
gem 'rack-attack'
gem 'ruby-saml', github: 'amoose/ruby-saml'
gem 'nokogiri-xmlsec-me-harder', '~> 0.9.1', require: 'xmlsec'
gem 'saml_idp', github: '18F/saml_idp'
gem 'sass-rails', '~> 5.0'
gem 'secure_headers', '~> 3.0.0'
gem 'sidekiq'
gem 'simple_form', github: 'amoose/simple_form', branch: 'feature/aria-invalid'
gem 'sinatra', require: false
gem 'slim-rails'
gem 'turbolinks'
gem 'twilio-ruby'
gem 'two_factor_authentication', path: '../two_factor_authentication/'
gem 'uglifier', '>= 1.3.0'
gem 'whenever', require: false
gem 'activerecord-session_store', '1.0.0.pre'

group :deploy do
  gem 'capistrano' # , '~> 3.4'
  gem 'capistrano-rails' # , '~> 1.1', require: false
  gem 'capistrano-rbenv' # , '~> 2.0', require: false
  gem 'capistrano-sidekiq'
end

group :development do
  gem 'better_errors'
  gem 'derailed'
  gem 'binding_of_caller'
  gem 'guard-rspec', require: false
  gem 'overcommit'
  gem 'quiet_assets'
  gem 'rack-mini-profiler'
  gem 'rails_layout'
  gem 'rubocop'
  gem 'slim_lint'
  gem 'spring'
  gem 'spring-commands-rspec'
  gem 'spring-watcher-listen'
end

group :development, :test do
  gem 'pry-byebug'
  gem 'rspec-rails', '~> 3.3'
  gem 'thin'
  gem 'bullet'
  gem 'mailcatcher', '0.6.3'
end

group :test do
  gem 'capybara-screenshot'
  gem 'codeclimate-test-reporter', require: nil
  gem 'database_cleaner'
  gem 'email_spec'
  gem 'factory_girl_rails'
  gem 'faker'
  gem 'poltergeist'
  gem 'rack_session_access'
  gem 'rack-test'
  gem 'shoulda-matchers', '~> 2.8', require: false
  gem 'sms-spec', git: 'https://github.com/monfresh/sms-spec.git', require: 'sms_spec'
  gem 'timecop'
  gem 'webmock'
end
