# DO NOT COMMIT TO MAIN!!! just for testing
# little helper script that I run to test things
# run via:
#   aws-vault exec prod-power -- bundle exec rails_runner query_test.rb

require 'reporting/cloudwatch_client'
require 'reporting/cloudwatch_query'

query = Reporting::CloudwatchQuery.new(
  names: ['User Registration: Email Confirmation'],
  limit: 10_000,
)

client = Reporting::CloudwatchClient.new

results = client.fetch(query:, from: 1.day.ago, to: 1.hour.ago)

# pp results
pp results.size
