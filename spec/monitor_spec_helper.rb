# This file is a version of spec_helper that doesn't load Rails, we use it when running
# monitor (smoke test) specs against deployed apps where we don't have access to the internals
require 'capybara/rspec'
require 'webdrivers/chromedriver'
require 'active_support/all'
require 'rspec/retry'

Time.zone ||= ActiveSupport::TimeZone['UTC']

Capybara.register_driver :chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--no-sandbox')
  options.add_argument('--window-size=1200x700')
  options.add_argument('--headless') if ENV['HEADLESS_BROWSER'] == 'true'
  options.add_argument('--disable-gpu') if ENV['HEADLESS_BROWSER'] == 'true'

  Capybara::Selenium::Driver.new app,
                                 browser: :chrome,
                                 capabilities: [options]
end

Capybara.javascript_driver = :chrome
Capybara.default_max_wait_time = 10
Capybara.automatic_label_click = true # USWDS styles native checkbox/radio as offscreen

Dir['spec/support/monitor/**/*.rb'].sort.each { |file| require File.expand_path(file) }

RSpec.configure do |config|
  config.color = true
  config.order = :random

  # show retry status in spec process
  config.verbose_retry = true
  # show exception that triggers a retry if verbose_retry is set to true
  config.display_try_failure_messages = true

  # config.infer_spec_type_from_file_location is a Rails-only feature,
  # so we do it ourselves.
  config.define_derived_metadata(file_path: %r{/spec/features/monitor}) do |metadata|
    metadata[:type] = :feature
    metadata[:js] = true

    # Can be overridden with RSPEC_RETRY_RETRY_COUNT
    metadata[:retry] = 3
  end

  config.example_status_persistence_file_path = './tmp/rspec-examples.txt'

  count = 1
  config.after do |example|
    next if !example.exception

    spec_name = example.description.strip.tr(' ', '_').dasherize.downcase

    dirname = "tmp/capybara/#{count}-#{spec_name}"
    FileUtils.mkdir_p(dirname)

    page.driver.browser.save_screenshot(File.join(dirname, 'screenshot.png'))
    File.open(File.join(dirname, 'page.html'), 'w') { |f| f.puts page.html }
    File.open(File.join(dirname, 'info.txt'), 'w') do |info|
      info.puts "example name: #{example.description}"
      info.puts "example location: #{example.location}"
      info.puts
      info.puts "current path: #{page.current_path}"
      info.puts "exception: #{example.exception.class} #{example.exception.message}"
    end

    count += 1
  end
end
