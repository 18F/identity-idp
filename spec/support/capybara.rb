require 'capybara/rspec'
require 'rack_session_access/capybara'
require 'extensions/capybara/node/simple'
require 'capybara/cuprite'
require 'capybara_mock/rspec'

# To pause and show browser call:
# page.driver.debug(binding)
show_browser = !!ENV['SHOW_BROWSER']

Capybara.register_driver(:headless_chrome) do |app|
  driver = Capybara::Cuprite::Driver.new(app, window_size: [1200, 700], inspector: show_browser, browser_options: { 'no-sandbox': nil })
  driver
end

Capybara.javascript_driver = :headless_chrome

Capybara.register_driver(:headless_chrome_mobile) do |app|
  driver = Capybara::Cuprite::Driver.new(app, window_size: [414, 736], inspector: true, browser_options: { 'no-sandbox': nil })
  user_agent_string = 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_5 like Mac OS X) ' \
                      'AppleWebKit/603.1.23 (KHTML, like Gecko) ' \
                      'HeadlessChrome/88.0.4324.150 Safari/602.1'

  driver.add_headers('User-Agent' => user_agent_string)
  driver
end

Capybara.server = :puma, { Silent: true }

Capybara.default_max_wait_time = (ENV['CAPYBARA_WAIT_TIME_SECONDS'] || 0).to_f
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
