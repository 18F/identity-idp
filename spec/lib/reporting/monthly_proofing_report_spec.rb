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
        ['started_gpo', 1, 1.0 / 5],
        ['started_in_person', 1, 1.0 / 5],
        ['started_fraud_review', 1, 1.0 / 5],
      ]

      aggregate_failures do
        csv.map(&:to_a).zip(expected_csv).each do |actual, expected|
          expect(actual).to eq(expected.map(&:to_s))
        end
      end
    end
  end

  describe '#data' do
    it 'counts unique users per event as a hash' do
      expect(report.data).to eq(
        'IdV: doc auth image upload vendor submitted' => 5,
        'IdV: final resolution' => 1,
        'IdV: USPS address letter requested' => 1,
        'USPS IPPaaS enrollment created' => 1,
        'IdV: Verify please call visited' => 1,
      )
    end
  end
end
