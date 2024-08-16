require 'rails_helper'
require 'reporting/monthly_idv_report'

RSpec.describe Reporting::MonthlyIdvReport do
  let(:end_date) { Date.new(2024, 9, 1).in_time_zone('UTC').end_of_day }
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
            idv_started: 264466,
            successfully_verified_users: 130372,
            blanket_proofing_rates: 0.49296317863165773,
            idv_final_resolution: 137216,
            idv_final_resolution_rate: 0.5188417414714935,
            verified_user_count: 0,
          ),
          instance_double(
            'Reporting::IdentityVerificationReport',
            time_range: Date.new(2024, 7, 1).all_month,
            idv_started: 364662,
            successfully_verified_users: 183509,
            blanket_proofing_rates: 0.5032303886887035,
            idv_final_resolution: 192148,
            idv_final_resolution_rate: 0.526920819827676,
            verified_user_count: 0,
          ),
          instance_double(
            'Reporting::IdentityVerificationReport',
            time_range: Date.new(2024, 8, 1).all_month,
            idv_started: 191502,
            successfully_verified_users: 85785,
            blanket_proofing_rates: 0.44795876805464174,
            idv_final_resolution: 89075,
            idv_final_resolution_rate: 0.46513874528725546,
            verified_user_count: 1,
          ),
        ],
      )
    end

    let(:expected_table) do
      [
        ['Metric', 'Jun 2024', 'Jul 2024', 'Aug 2024'],
        ['IDV started', 264466, 364662, 191502],
        ['# of successfully verified users', 130372, 183509, 85785],
        ['% IDV started to successfully verified', 0.49296317863165773, 0.5032303886887035,
         0.44795876805464174],
        ['# of workflow completed', 137216, 192148, 89075],
        ['% rate of workflow completed', 0.5188417414714935, 0.526920819827676,
         0.46513874528725546],
        ['# of users verified (total)', 0, 0, 1],
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
        expect(Reporting::IdentityVerificationReport).to receive(:new).
          with(issuers: nil, time_range: month, cloudwatch_client: anything)
      end

      subject.monthly_subreports
    end
  end
end
