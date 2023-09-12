require 'bundler/setup'
Bundler.setup

# Knapsack runs the tests across multiple nodes in CI. We do not need to run it
# locally unless we are generating a report to help it figure out how to
# distribute tests across nodes.
if ENV['CI'] || ENV['KNAPSACK_GENERATE_REPORT']
  require 'knapsack'
  Knapsack::Adapters::RSpecAdapter.bind
end
ENV['RACK_ENV'] ||= 'test'
ENV['RAILS_ENV'] ||= 'test'

require_relative '../config/environment'
require 'rails/test_help'
require 'active_support/core_ext/object/blank'
require 'active_support'
require 'sequent/test'
# require 'database_cleaner'

require_relative '../blog'

# Sequent::Test::DatabaseHelpers.maintain_test_database_schema(env: 'test')

module DomainTests
  def self.included(base)
    base.metadata[:domain_tests] = true
  end
end

RSPEC_RUNNING_IN_PARALLEL = ENV['PARALLEL_PID_FILE'].present?

RSpec.configure do |config|
  # see more settings at spec/rails_helper.rb
  config.disable_monkey_patching!
  config.raise_errors_for_deprecations!
  config.order = :random
  config.color = true
  config.formatter = if ENV['CI'] || RSPEC_RUNNING_IN_PARALLEL
                       :progress
                     else
                       :documentation
                     end

  # allows you to run only the failures from the previous run:
  # rspec --only-failures
  config.example_status_persistence_file_path = './tmp/rspec-examples.txt'

  # show the n slowest tests at the end of the test run
  config.profile_examples = RSPEC_RUNNING_IN_PARALLEL ? 10 : 0

  config.include Sequent::Test::CommandHandlerHelpers
  config.include DomainTests, file_path: /spec\/cqrs/

  # Domain tests run with a clean sequent configuration and the in memory FakeEventStore
  config.around :each, :domain_tests do |example|
    old_config = Sequent.configuration
    Sequent::Configuration.reset
    Sequent.configuration.event_store = Sequent::Test::CommandHandlerHelpers::FakeEventStore.new
    Sequent.configuration.event_handlers = []
    example.run
  ensure
    Sequent::Configuration.restore(old_config)
  end

  config.around do |example|
    Sequent.configuration.aggregate_repository.clear
    # DatabaseCleaner.clean_with(:truncation, {except: Sequent::Migrations::ViewSchema::Versions.table_name})
    # DatabaseCleaner.cleaning do
    # ensure
    #   Sequent.configuration.aggregate_repository.clear
    # end
    example.run
  end
end

require 'webmock/rspec'
WebMock.disable_net_connect!(
  allow: [
    /localhost/,
    /127\.0\.0\.1/,
    /codeclimate.com/, # For uploading coverage reports
    /chromedriver\.storage\.googleapis\.com/, # For fetching a chromedriver binary
  ],
)

require 'zonebie'
Zonebie.quiet = true
require 'zonebie/rspec'

RSpec::Expectations.configuration.on_potential_false_positives = :nothing
