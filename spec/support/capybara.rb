require 'capybara/rspec'
require 'capybara-screenshot/rspec'
require 'rack_session_access/capybara'
require "selenium/webdriver"

Capybara.register_driver :headless_chrome do |app|
  capabilities = Selenium::WebDriver::Remote::Capabilities.chrome(
    chromeOptions: { args: %w[headless disable-gpu] }
  )

  Capybara::Selenium::Driver.new app,
    browser: :chrome,
    desired_capabilities: capabilities
end

Capybara.javascript_driver = :headless_chrome
Chromedriver.set_version '2.37'

Capybara.default_max_wait_time = 5
Capybara::Screenshot.autosave_on_failure = false
Capybara.asset_host = ENV['RAILS_ASSET_HOST'] || 'http://localhost:3000'

Capybara.register_driver(:mobile_rack_test) do |app|
  user_agent_string = 'Mozilla/5.0 (iPhone; CPU iPhone OS 10_3_2 like Mac OS X) ' \
                      'AppleWebKit/603.2.4 (KHTML, like Gecko) ' \
                      'Version/10.0 Mobile/14F89 Safari/602.1'
  Capybara::RackTest::Driver.new(app, headers: { 'HTTP_USER_AGENT' => user_agent_string })
end

Capybara.register_driver(:desktop_rack_test) do |app|
  user_agent_string = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) ' \
                      'AppleWebKit/537.36 (KHTML, like Gecko) ' \
                      'Chrome/58.0.3029.110 Safari/537.36'
  Capybara::RackTest::Driver.new(app, headers: { 'HTTP_USER_AGENT' => user_agent_string })
end

Capybara.default_driver = :desktop_rack_test
