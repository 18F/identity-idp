require 'rails_helper'
require 'reporting/authentication_report'

RSpec.describe Reporting::AuthenticationReport do
  let(:issuer) { 'my:example:issuer' }
  let(:time_range) { Date.new(2022, 1, 1).all_day }

  subject(:report) { Reporting::AuthenticationReport.new(issuer:, time_range:) }

  before do
    cloudwatch_client = double(
      'Reporting::CloudwatchClient',
      fetch: [
        # finishes funnel
        { 'user_id' => 'user1', 'name' => 'OpenID Connect: authorization request' },
        { 'user_id' => 'user1', 'name' => 'User Registration: Email Confirmation' },
        { 'user_id' => 'user1', 'name' => 'User Registration: 2FA Setup visited' },
        { 'user_id' => 'user1', 'name' => 'User Registration: User Fully Registered' },
        { 'user_id' => 'user1', 'name' => 'SP redirect initiated' },

        # first 3 steps
        { 'user_id' => 'user2', 'name' => 'OpenID Connect: authorization request' },
        { 'user_id' => 'user2', 'name' => 'User Registration: Email Confirmation' },
        { 'user_id' => 'user2', 'name' => 'User Registration: 2FA Setup visited' },
        { 'user_id' => 'user2', 'name' => 'User Registration: User Fully Registered' },

        # first 2 steps
        { 'user_id' => 'user3', 'name' => 'OpenID Connect: authorization request' },
        { 'user_id' => 'user3', 'name' => 'User Registration: Email Confirmation' },
        { 'user_id' => 'user3', 'name' => 'User Registration: 2FA Setup visited' },

        # first step only
        { 'user_id' => 'user4', 'name' => 'OpenID Connect: authorization request' },
        { 'user_id' => 'user4', 'name' => 'User Registration: Email Confirmation' },

        # already existing user, just signing in
        { 'user_id' => 'user5', 'name' => 'OpenID Connect: authorization request' },
        { 'user_id' => 'user5', 'name' => 'SP redirect initiated' },
      ],
    )

    allow(report).to receive(:cloudwatch_client).and_return(cloudwatch_client)
  end

  describe '#to_csv' do
    it 'generates a csv' do
      csv = CSV.parse(report.to_csv, headers: false)

      expected_csv = [
        ['Report Timeframe', "#{time_range.begin} to #{time_range.end}"],
        ['Report Generated', Date.today.to_s], # rubocop:disable Rails/Date
        ['Issuer', issuer],
        [],
        ['Metric', 'Number of accounts', '% of total from start'],
        ['New Users Started IAL1 Verification', '4', '100.0%'],
        ['New Users Completed IAL1 Password Setup', '3', '75.0%'],
        ['New Users Completed IAL1 MFA', '2', '50.0%'],
        ['New IAL1 Users Consented to Partner', '1', '25.0%'],
        [],
        ['Total # of IAL1 Users', '2'],
        [],
        ['AAL2 Authentication Requests from Partner', '5', '100.0%'],
        ['AAL2 Authenticated Requests', '2', '40.0%'],
      ]

      aggregate_failures do
        csv.map(&:to_a).zip(expected_csv).each do |actual, expected|
          expect(actual).to eq(expected)
        end
      end
    end
  end
end
