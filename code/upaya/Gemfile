source 'https://rubygems.org'
ruby '2.3.0'

gem 'rails', '~> 4.2.6'

gem 'attr_encrypted'
gem 'autoprefixer-rails', '~> 5.2'
gem 'coffee-rails', '~> 4.1.0'
gem 'devise'
gem 'devise_security_extension'
gem 'dotiw'
gem 'figaro'
gem 'jbuilder', '~> 2.0'
gem 'jquery-rails'
gem 'jquery-ui-rails'
gem 'kaminari-bootstrap', '~> 3.0.1'
gem 'letter_opener_web'
gem 'lograge'
gem 'newrelic_rpm'
gem 'omniauth-saml', github: 'amoose/omniauth-saml', branch: 'feature/internal_idp'
gem 'phony_rails'
gem 'pg'
gem 'pundit'
gem 'valid_email'
gem 'rack-attack'
gem 'responders', '~> 2.0'
gem 'ruby-saml', github: 'amoose/ruby-saml'
# gem 'nokogiri-xmlsec-me-harder', '~> 0.9.1', require: 'xmlsec'
gem 'saml_idp', github: '18F/saml_idp'
gem 'sass-rails', '~> 5.0'
gem 'secure_headers', '~> 3.0.0'
gem 'sidekiq'
gem 'simple_form', github: 'amoose/simple_form', branch: 'feature/aria-invalid'
gem 'slim-rails'
gem 'turbolinks'
gem 'twilio-ruby'
gem 'two_factor_authentication', git: 'https://github.com/Houdini/two_factor_authentication'
gem 'uglifier', '>= 1.3.0'
gem 'whenever', require: false
gem 'activerecord-session_store', '1.0.0.pre'

group :deploy do
  gem 'berkshelf'
  gem 'capistrano' # , '~> 3.4'
  gem 'capistrano-rails' # , '~> 1.1', require: false
  gem 'capistrano-rbenv' # , '~> 2.0', require: false
  gem 'capistrano-resque' # , '~> 0.2.1', require: false
  gem 'chef', '~> 12.0.1'
  gem 'knife-ec2'
  gem 'knife-solo', github: 'matschaffer/knife-solo', submodules: true
  gem 'knife-solo_data_bag'
end

group :development do
  gem 'aws-sdk', '~> 2.0'
  gem 'better_errors'
  gem 'derailed'
  gem 'binding_of_caller'
  gem 'guard-rspec', require: false
  gem 'quiet_assets'
  gem 'rack-mini-profiler'
  gem 'rails_layout'
  gem 'spring'
  gem 'spring-commands-rspec'
  gem 'spring-watcher-listen'
end

group :development, :test do
  gem 'pry-byebug'
  gem 'rspec-rails', '~> 3.3'
  gem 'thin'
  gem 'brakeman'
  gem 'bullet'
  gem 'dawnscanner', require: false
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
  gem 'rspec-activejob'
  gem 'rubocop'
  gem 'shoulda-matchers', '~> 2.8', require: false
  gem 'sinatra', require: false
  gem 'sms-spec', git: 'https://github.com/monfresh/sms-spec.git', require: 'sms_spec'
  gem 'timecop'
  gem 'webmock'
end
