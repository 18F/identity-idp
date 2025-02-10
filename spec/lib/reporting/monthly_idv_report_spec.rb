require 'rails_helper'
require 'reporting/monthly_idv_report'

RSpec.describe Reporting::MonthlyIdvReport do
  let(:end_date) { Date.new(2024, 9, 1).in_time_zone('UTC').yesterday.end_of_day }
  let(:parallel) { true }

  subject(:idv_report) do
    described_class.new(end_date: end_date, parallel: parallel)
  end

  describe '#as_csv' do
    before do
      allow(idv_report).to receive(:reports).and_return(
        [
          instance_double(
            'Reporting::IdentityVerificationReport',
            time_range: Date.new(2024, 6, 1).all_month,
            idv_started: 1111,
            successfully_verified_users: 1111,
            blanket_proofing_rate: 0.1111,
            idv_final_resolution: 1111,
            idv_final_resolution_rate: 0.1111,
            verified_user_count: 1111,
          ),
          instance_double(
            'Reporting::IdentityVerificationReport',
            time_range: Date.new(2024, 7, 1).all_month,
            idv_started: 2222,
            successfully_verified_users: 2222,
            blanket_proofing_rate: 0.2222,
            idv_final_resolution: 2222,
            idv_final_resolution_rate: 0.2222,
            verified_user_count: 2222,
          ),
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
        ['Metric', 'Jun 2024', 'Jul 2024', 'Aug 2024'],
        ['IDV started', 1111, 2222, 3333],
        ['# of successfully verified users', 1111, 2222, 3333],
        ['% IDV started to successfully verified', 0.1111, 0.2222,
         0.3333],
        ['# of workflow completed', 1111, 2222, 3333],
        ['% rate of workflow completed', 0.1111, 0.2222,
         0.3333],
        ['# of users verified (total)', 1111, 2222, 3333],
      ]
    end

    it 'reports 3 months of data' do
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
    let(:june) { Date.new(2024, 6, 1).in_time_zone('UTC').all_month }
    let(:july) { Date.new(2024, 7, 1).in_time_zone('UTC').all_month }
    let(:august) { Date.new(2024, 8, 1).in_time_zone('UTC').all_month }

    it 'returns IdV reports for the expected months' do
      [june, july, august].each do |month|
        expect(Reporting::IdentityVerificationReport).to receive(:new)
          .with(issuers: nil, time_range: month, cloudwatch_client: anything)
      end

      subject.monthly_subreports
    end
  end
end
