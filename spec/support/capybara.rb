require 'capybara/rspec'
require 'capybara-screenshot/rspec'
require 'rack_session_access/capybara'
require 'webdrivers/chromedriver'
require 'selenium/webdriver'

Capybara.register_driver :headless_chrome do |app|
  browser_options = Selenium::WebDriver::Chrome::Options.new
  browser_options.args << '--headless' if !ENV['SHOW_BROWSER']
  browser_options.args << '--disable-gpu' if !ENV['SHOW_BROWSER']
  browser_options.args << '--no-sandbox'
  browser_options.args << '--disable-dev-shm-usage'

  Capybara::Selenium::Driver.new app,
                                 browser: :chrome,
                                 options: browser_options
end
Capybara.javascript_driver = :headless_chrome
Webdrivers.cache_time = 86_400

Capybara.register_driver(:headless_chrome_mobile) do |app|
  user_agent_string = 'Mozilla/5.0 (iPhone; CPU iPhone OS 10_3_2 like Mac OS X) ' \
                      'AppleWebKit/537.36 (KHTML, like Gecko) ' \
                      'HeadlessChrome/88.0.4324.150 Safari/537.36'

  browser_options = Selenium::WebDriver::Chrome::Options.new
  browser_options.args << '--headless' if !ENV['SHOW_BROWSER']
  browser_options.args << '--disable-gpu' if !ENV['SHOW_BROWSER']
  browser_options.args << '--no-sandbox'
  browser_options.args << '--disable-dev-shm-usage'
  browser_options.args << '--window-size=414,736'
  browser_options.args << "--user-agent='#{user_agent_string}'"
  browser_options.args << '--use-fake-device-for-media-stream'

  Capybara::Selenium::Driver.new app,
                                 browser: :chrome,
                                 options: browser_options
end

Capybara.server = :puma, { Silent: true }

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
