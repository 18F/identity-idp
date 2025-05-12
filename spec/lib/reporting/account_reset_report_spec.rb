require 'rails_helper'
require 'reporting/proofing_rate_report'

RSpec.describe Reporting::ProofingRateReport do
  let(:end_date) { Date.new(2022, 1, 1).in_time_zone('UTC').end_of_day }
  let(:parallel) { true }

  subject(:report) do
    Reporting::AccountDeletionRateReport.new(end_date: end_date, wait_duration: 0, parallel: parallel)
  end

  describe '#as_csv' do
    before do
      allow(report).to receive(:reports).and_return(
        [
          instance_double(
            'Reporting::AccountResetReport',
            account_reset_delete: 0.25,
            email_password_auth: 0.3333333333333333,
            account_reset_rate: 0.5,
            time_range: (end_date - 30.days).beginning_of_day..end_date,
          )
        ],
      )
    end

    context 'when hitting a Cloudwatch rate limit' do
      before do
        stub_const('CloudwatchClient::DEFAULT_WAIT_DURATION', 0)

        allow(report).to receive(:reports).and_call_original

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
        expect(report.as_csv).to eq(
          [
            ['Error', 'Message'],
            ['Aws::CloudWatchLogs::Errors::ThrottlingException', 'Rate exceeded'],
          ],
        )
      end
    end
  end

  describe '#reports' do
    before do
      query_id = SecureRandom.hex

      Aws.config[:cloudwatchlogs] = {
        stub_responses: {
          start_query: { query_id: query_id },
          get_query_results: {
            status: 'Complete',
            results: [],
          },
        },
      }
    end

    [true, false].each do |parallel_value|
      context "with parallel: #{parallel_value}" do
        let(:parallel) { parallel_value }

        it 'calls IdentityVerificationReport with separate slices, but merges them' do
          allow(Reporting::IdentityVerificationReport).to receive(:new).and_call_original

          expect(report.reports.map(&:time_range)).to eq(
            [
              (end_date - 30.days).beginning_of_day..end_date,
              (end_date - 60.days).beginning_of_day..end_date,
              (end_date - 90.days).beginning_of_day..end_date,
            ],
          )

          expect(Reporting::IdentityVerificationReport).to have_received(:new).with(
            time_range: (end_date - 30.days).beginning_of_day..end_date,
            issuers: nil,
            cloudwatch_client: report.cloudwatch_client,
          ).once

          expect(Reporting::IdentityVerificationReport).to have_received(:new).with(
            time_range: (end_date - 60.days).beginning_of_day..(end_date - 30.days).end_of_day,
            issuers: nil,
            cloudwatch_client: report.cloudwatch_client,
          ).once

          expect(Reporting::IdentityVerificationReport).to have_received(:new).with(
            time_range: (end_date - 90.days).beginning_of_day..(end_date - 60.days).end_of_day,
            issuers: nil,
            cloudwatch_client: report.cloudwatch_client,
          ).once
        end
      end
    end
  end
end
