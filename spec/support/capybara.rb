require 'capybara/rspec'
require 'rack_session_access/capybara'
require 'webdrivers/chromedriver'
require 'selenium/webdriver'

Capybara.register_driver :headless_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless') if !ENV['SHOW_BROWSER']
  options.add_argument('--disable-gpu') if !ENV['SHOW_BROWSER']
  options.add_argument('--window-size=1200x700')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument("--proxy-server=127.0.0.1:#{Capybara::Webmock.port_number}")

  Capybara::Selenium::Driver.new app,
                                 browser: :chrome,
                                 capabilities: [options]
end
Capybara.javascript_driver = :headless_chrome
Webdrivers.cache_time = 86_400

Capybara.register_driver(:headless_chrome_mobile) do |app|
  user_agent_string = 'Mozilla/5.0 (iPhone; CPU iPhone OS 10_3_2 like Mac OS X) ' \
                      'AppleWebKit/537.36 (KHTML, like Gecko) ' \
                      'HeadlessChrome/88.0.4324.150 Safari/537.36'

  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless') if !ENV['SHOW_BROWSER']
  options.add_argument('--disable-gpu') if !ENV['SHOW_BROWSER']
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--window-size=414,736')
  options.add_argument("--user-agent='#{user_agent_string}'")
  options.add_argument('--use-fake-device-for-media-stream')
  options.add_argument("--proxy-server=127.0.0.1:#{Capybara::Webmock.port_number}")

  Capybara::Selenium::Driver.new app,
                                 browser: :chrome,
                                 capabilities: [options]
end

Capybara.server = :puma, { Silent: true }

Capybara.default_max_wait_time = (ENV['CAPYBARA_WAIT_TIME_SECONDS'] || '0.5').to_f
Capybara.asset_host = ENV['RAILS_ASSET_HOST'] || 'http://localhost:3000'
Capybara.automatic_label_click = true # USWDS styles native checkbox/radio as offscreen
Capybara.enable_aria_label = true

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
