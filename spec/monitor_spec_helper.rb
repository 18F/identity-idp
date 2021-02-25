# This file is a version of spec_helper that doesn't load Rails, we use it when running
# monitor (smoke test) specs against deployed apps where we don't have access to the internals
require 'capybara/rspec'
require 'webdrivers/chromedriver'
require 'active_support/all'

Time.zone ||= ActiveSupport::TimeZone['UTC']

Capybara.register_driver :chrome do |app|
  browser_options = Selenium::WebDriver::Chrome::Options.new
  browser_options.args << '--no-sandbox'
  browser_options.args << '--window-size=1200x700'
  browser_options.args << '--headless' if ENV['HEADLESS_BROWSER'] == 'true'
  browser_options.args << '--disable-gpu' if ENV['HEADLESS_BROWSER'] == 'true'

  Capybara::Selenium::Driver.new app,
                                 browser: :chrome,
                                 options: browser_options
end

Capybara.javascript_driver = :chrome
Capybara.default_max_wait_time = 10

Dir['spec/support/monitor/**/*.rb'].sort.each { |file| require File.expand_path(file) }

RSpec.configure do |config|
  config.color = true
  config.order = :random

  # config.infer_spec_type_from_file_location is a Rails-only feature,
  # so we do it ourselves.
  config.define_derived_metadata(file_path: %r{/spec/features/monitor}) do |metadata|
    metadata[:type] = :feature
    metadata[:js] = true
  end

  config.example_status_persistence_file_path = './tmp/rspec-examples.txt'
end
