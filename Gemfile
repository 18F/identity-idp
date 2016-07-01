source 'https://rubygems.org'
git_source(:github) { |repo_name| "https://github.com/#{repo_name}.git" }

gem 'rails', '~> 4.2.6'

gem 'browserify-rails'
gem 'coffee-rails', '~> 4.1.0'
gem 'devise', '~> 4.1'
gem 'dotiw'
gem 'figaro'
gem 'lograge'
gem 'newrelic_rpm'
gem 'omniauth-saml'
gem 'phony_rails'
gem 'pg'
gem 'pundit'
gem 'valid_email'
gem 'rack-attack'
gem 'ruby-saml'
gem 'saml_idp', '~> 0.3.1'
gem 'sass-rails', '~> 5.0'
gem 'secure_headers', '~> 3.0'
gem 'sidekiq'
gem 'simple_form'
gem 'sinatra', require: false
gem 'slim-rails'
gem 'turbolinks'
gem 'twilio-ruby'
gem 'two_factor_authentication', github: 'Houdini/two_factor_authentication'
gem 'uglifier', '>= 1.3.0'
gem 'whenever', require: false
gem 'xmlenc', '~> 0.6.4'
gem 'activerecord-session_store', '1.0.0.pre'

group :deploy do
  gem 'capistrano' # , '~> 3.4'
  gem 'capistrano-rails' # , '~> 1.1', require: false
  gem 'capistrano-rbenv' # , '~> 2.0', require: false
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
  gem 'rack-mini-profiler'
  gem 'rails_layout'
  gem 'rubocop', require: false
  gem 'slim_lint'
  gem 'spring'
  gem 'spring-commands-rspec'
  gem 'spring-watcher-listen'
end

group :development, :test do
  gem 'i18n-tasks'
  gem 'pry-byebug'
  gem 'rspec-rails', '~> 3.3'
  gem 'thin'
  gem 'bullet'
  gem 'mailcatcher', require: false
end

group :test do
  gem 'capybara-screenshot'
  gem 'codeclimate-test-reporter', require: false
  gem 'database_cleaner'
  gem 'email_spec'
  gem 'factory_girl_rails'
  gem 'faker'
  gem 'poltergeist'
  gem 'rack_session_access'
  gem 'rack-test'
  gem 'shoulda-matchers', '~> 2.8', require: false
  gem 'sms-spec', github: 'monfresh/sms-spec', require: 'sms_spec'
  gem 'test_after_commit'
  gem 'timecop'
  gem 'webmock'
end
