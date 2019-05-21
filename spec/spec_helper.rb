# Knapsack runs the tests across multiple nodes in CI. We do not need to run it
# locally unless we are generating a report to help it figure out how to
# distribute tests across nodes.
if ENV['CI'] || ENV['KNAPSACK_GENERATE_REPORT']
  require 'knapsack'
  Knapsack::Adapters::RSpecAdapter.bind
end

RSpec.configure do |config|
  # see more settings at spec/rails_helper.rb
  config.raise_errors_for_deprecations!
  config.order = :random
  config.color = true

  # allows you to run only the failures from the previous run:
  # rspec --only-failures
  config.example_status_persistence_file_path = './tmp/rspec-examples.txt'

  # show the n slowest tests at the end of the test run
  # config.profile_examples = 10

  # Skip user_flow specs in default tasks
  config.filter_run_excluding user_flow: true
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
