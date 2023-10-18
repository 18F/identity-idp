require 'rails_helper'
require 'reporting/monthly_proofing_report'

RSpec.describe Reporting::MonthlyProofingReport do
  let(:time_range) { Date.new(2022, 1, 1).all_month }

  subject(:report) { Reporting::MonthlyProofingReport.new(time_range:) }

  before do
    cloudwatch_client = double(
      'Reporting::CloudwatchClient',
      fetch: [
        # Success
        { 'user_id' => 'user1', 'name' => 'IdV: doc auth image upload vendor submitted' },
        { 'user_id' => 'user1', 'name' => 'IdV: final resolution' },

        # Letter requested user
        { 'user_id' => 'user2', 'name' => 'IdV: doc auth image upload vendor submitted' },
        { 'user_id' => 'user2', 'name' => 'IdV: USPS address letter requested' },

        # Fraud review user
        { 'user_id' => 'user3', 'name' => 'IdV: doc auth image upload vendor submitted' },
        { 'user_id' => 'user3', 'name' => 'IdV: Verify please call visited' },

        # In-person user
        { 'user_id' => 'user4', 'name' => 'IdV: doc auth image upload vendor submitted' },
        { 'user_id' => 'user4', 'name' => 'USPS IPPaaS enrollment created' },

        # Incomplete user
        { 'user_id' => 'user5', 'name' => 'IdV: doc auth image upload vendor submitted' },
      ],
    )

    allow(report).to receive(:cloudwatch_client).and_return(cloudwatch_client)
  end

  describe '#to_csv' do
    it 'generates a csv' do
      csv = CSV.parse(report.to_csv, headers: false)

      expected_csv = [
        ['report_start', time_range.begin.iso8601],
        ['report_end', time_range.end.iso8601],
        ['report_generated', Date.today.to_s], # rubocop:disable Rails/Date
        ['metric', 'num_users', 'percent'],
        ['image_submitted', 5, 5.0 / 5],
        ['verified', 1, 1.0 / 5],
        ['not_verified_started_gpo', 1, 1.0 / 5],
        ['not_verified_started_in_person', 1, 1.0 / 5],
        ['not_verified_started_fraud_review', 1, 1.0 / 5],
      ]

      aggregate_failures do
        csv.map(&:to_a).zip(expected_csv).each do |actual, expected|
          expect(actual).to eq(expected.map(&:to_s))
        end
      end
    end
  end

  describe '#proofing_report' do
    context 'when the data is outside the log retention range' do
      before do
        allow(report.cloudwatch_client).to receive(:fetch).and_raise(
          Aws::CloudWatchLogs::Errors::MalformedQueryException.new(
            nil,
            'exceeds the log groups log retention settings',
          ),
        )
      end

      it 'handles the error and returns a table with information on the error' do
        expect(report.proofing_report).to match(
          [
            ['Error', 'Message'],
            ['Aws::CloudWatchLogs::Errors::MalformedQueryException', kind_of(String)],
          ],
        )
      end
    end
  end

  describe '#data' do
    it 'keeps unique users per event as a hash' do
      expect(report.data).to eq(
        'IdV: doc auth image upload vendor submitted' => %w[user1 user2 user3 user4 user5].to_set,
        'IdV: final resolution' => %w[user1].to_set,
        'IdV: USPS address letter requested' => %w[user2].to_set,
        'IdV: Verify please call visited' => %w[user3].to_set,
        'USPS IPPaaS enrollment created' => %w[user4].to_set,
      )
    end
  end
end
