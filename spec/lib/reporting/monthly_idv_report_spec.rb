require 'rails_helper'
require 'reporting/monthly_idv_report'

RSpec.describe Reporting::MonthlyIdvReport do
  let(:end_date) { Date.new(2024, 9, 1).in_time_zone('UTC').yesterday.end_of_day }
  let(:parallel) { true }

  subject(:idv_report) do
    Reporting::MonthlyIdvReport.new(end_date: end_date, parallel: parallel)
  end

  describe '#as_csv' do
    before do
      allow(idv_report).to receive(:reports).and_return(
        [
          instance_double(
            'Reporting::IdentityVerificationReport',
            time_range: Date.new(2024, 8, 1).all_month,
            idv_started: 3333,
            successfully_verified_users: 3333,
            blanket_proofing_rate: 0.3333,
            idv_final_resolution: 3333,
            idv_final_resolution_rate: 0.3333,
            verified_user_count: 3333,
          ),
        ],
      )
    end

    let(:expected_table) do
      [
        ['Metric', 'Aug 2024'],
        ['IDV started', 3333],
        ['# of successfully verified users', 3333],
        ['% IDV started to successfully verified', 0.3333],
        ['# of workflow completed', 3333],
        ['% rate of workflow completed', 0.3333],
        ['# of users verified (total)', 3333],
      ]
    end

    it 'reports 1 month of data' do
      idv_report.as_csv.zip(expected_table).each do |actual, expected|
        expect(actual).to eq(expected)
      end
    end

    # copied-and-pasted; should this go somewhere else?
    context 'when hitting a Cloudwatch rate limit' do
      before do
        stub_const('CloudwatchClient::DEFAULT_WAIT_DURATION', 0)

        allow(idv_report).to receive(:reports).and_call_original

        Aws.config[:cloudwatchlogs] = {
          stub_responses: {
            start_query: Aws::CloudWatchLogs::Errors::ThrottlingException.new(
              nil,
              'Rate exceeded',
            ),
          },
        }
      end

      it 'renders an error table' do
        expect(idv_report.as_csv).to eq(
          [
            ['Error', 'Message'],
            ['Aws::CloudWatchLogs::Errors::ThrottlingException', 'Rate exceeded'],
          ],
        )
      end
    end
  end

  describe '#monthly_subreports' do
    let(:august) { Date.new(2024, 8, 1).in_time_zone('UTC').all_month }

    it 'returns IdV report for the expected month' do
      expect(Reporting::IdentityVerificationReport).to receive(:new)
        .with(issuers: nil, time_range: august, cloudwatch_client: anything)

      subject.monthly_subreports
    end
  end
end
