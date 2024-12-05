# Knapsack runs the tests across multiple nodes in CI. We do not need to run it
# locally unless we are generating a report to help it figure out how to
# distribute tests across nodes.
if ENV['CI'] || ENV['KNAPSACK_GENERATE_REPORT']
  require 'knapsack'
  Knapsack::Adapters::RSpecAdapter.bind
end

require 'active_support/core_ext/object/blank'
require 'active_support'

RSPEC_RUNNING_IN_PARALLEL = ENV['PARALLEL_PID_FILE'].present?.freeze

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
end

require 'retries'
Retries.sleep_enabled = false

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
if !ENV['CI']
  Zonebie.quiet = true
end
require 'zonebie/rspec'

RSpec::Expectations.configuration.on_potential_false_positives = :nothing

# Shared helper methods used in multiple files
def assert_error_messages_equal(err, expected)
  actual = normalize_error_message(err.message)
  expected = normalize_error_message(expected)
  expect(actual).to eql(expected)
end

def normalize_error_message(message)
  message.
    gsub(/\x1b\[[0-9;]*m/, ''). # Strip ANSI control characters used for color
    gsub(/:0x[0-9a-f]{16}/, ':<id>').
    strip
end
