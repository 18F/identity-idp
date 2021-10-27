# This file is copied to spec/ when you run 'rails generate rspec:install'

if ENV['COVERAGE']
  require './spec/simplecov_helper'
  SimplecovHelper.start
end

ENV['RAILS_ENV'] = 'test'

require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_unit/railtie'
require 'rspec/rails'
require 'spec_helper'
require 'email_spec'
require 'factory_bot'
require 'view_component/test_helpers'
require 'capybara/rspec'

# Checks for pending migrations before tests are run.
# If you are not using ActiveRecord, you can remove this line.
ActiveRecord::Migration.maintain_test_schema!

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!

  config.include ActiveSupport::Testing::TimeHelpers
  config.include EmailSpec::Helpers
  config.include EmailSpec::Matchers
  config.include AbstractController::Translation
  config.include Features::MailerHelper, type: :feature
  config.include Features::SessionHelper, type: :feature
  config.include Features::StripTagsHelper, type: :feature
  config.include ViewComponent::TestHelpers, type: :component
  config.include Capybara::RSpecMatchers, type: :component
  config.include AgreementsHelper
  config.include AnalyticsHelper
  config.include AwsKmsClientHelper
  config.include KeyRotationHelper
  config.include OtpHelper
  config.include XmlHelper

  config.before(:suite) do
    Rails.application.load_seed

    class Analytics
      prepend FakeAnalytics::PiiAlerter
    end

    begin
      REDIS_POOL.with { |namespaced| namespaced.redis.info }
    rescue RuntimeError => error
      puts error
      puts 'It appears Redis is not running, but it is required for (some) specs to run'
      exit 1
    end
  end

  config.before(:each) do
    I18n.locale = :en
  end

  config.before(:each, js: true) do
    allow(IdentityConfig.store).to receive(:domain_name).and_return('127.0.0.1')
    server = Capybara.current_session.server
    allow(Rails.application.routes).to receive(:default_url_options).and_return(
      Rails.application.routes.default_url_options.merge(host: "#{server.host}:#{server.port}"),
    )
  end

  config.before(:each, type: :controller) do
    @request.host = IdentityConfig.store.domain_name
  end

  config.before(:each) do
    allow(ValidateEmail).to receive(:mx_valid?).and_return(true)
  end

  config.before(:each) do
    Telephony::Test::Message.clear_messages
    Telephony::Test::Call.clear_calls
    PushNotification::LocalEventQueue.clear!
  end

  config.before(:each) do
    DocAuth::Mock::DocAuthMockClient.reset!
    original_queue_adapter = ActiveJob::Base.queue_adapter
    descendants = ActiveJob::Base.descendants + [ActiveJob::Base]

    ActiveJob::Base.queue_adapter = :inline
    descendants.each(&:disable_test_adapter)
  end

  config.around(:each, type: :feature) do |example|
    Bullet.enable = true
    example.run
    Bullet.enable = false
  end
end
