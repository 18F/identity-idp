require 'capybara/rspec'
require 'capybara-screenshot/rspec'
require 'capybara/poltergeist'
require 'rack_session_access/capybara'

Capybara.javascript_driver = :poltergeist
Capybara.default_max_wait_time = 5
Capybara::Screenshot.autosave_on_failure = false
Capybara.asset_host = ENV['RAILS_ASSET_HOST'] || 'http://localhost:3000'
