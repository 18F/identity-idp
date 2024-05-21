require 'rails_helper'
require 'reporting/proofing_rate_report'

RSpec.describe Reporting::ProofingRateReport do
  let(:end_date) { Date.new(2022, 1, 1).in_time_zone('UTC').end_of_day }
  let(:parallel) { true }

  subject(:report) do
    Reporting::ProofingRateReport.new(end_date: end_date, wait_duration: 0, parallel: parallel)
  end

  describe '#as_csv' do
    before do
      allow(report).to receive(:reports).and_return(
        [
          instance_double(
            'Reporting::IdentityVerificationReport',
            blanket_proofing_rates: 0.25,
            intent_proofing_rates: 0.3333333333333333,
            actual_proofing_rates: 0.5,
            industry_proofing_rates: 0.5,
            idv_started: 4,
            idv_doc_auth_welcome_submitted: 3,
            idv_doc_auth_image_vendor_submitted: 2,
            successfully_verified_users: 1,
            idv_doc_auth_rejected: 1,
            idv_fraud_rejected: 0,
            time_range: (end_date.beginning_of_day - 30.days)..end_date,
          ),
          instance_double(
            'Reporting::IdentityVerificationReport',
            blanket_proofing_rates: 0.4,
            intent_proofing_rates: 0.5,
            actual_proofing_rates: 0.6666666666666666,
            industry_proofing_rates: 0.6666666666666666,
            idv_started: 5,
            idv_doc_auth_welcome_submitted: 4,
            idv_doc_auth_image_vendor_submitted: 3,
            successfully_verified_users: 2,
            idv_doc_auth_rejected: 1,
            idv_fraud_rejected: 1,
            time_range: (end_date.beginning_of_day - 60.days)..end_date,
          ),
          instance_double(
            'Reporting::IdentityVerificationReport',
            blanket_proofing_rates: 0.5,
            intent_proofing_rates: 0.6,
            actual_proofing_rates: 0.75,
            industry_proofing_rates: 0.75,
            idv_started: 6,
            idv_doc_auth_welcome_submitted: 5,
            idv_doc_auth_image_vendor_submitted: 4,
            successfully_verified_users: 3,
            idv_doc_auth_rejected: 1,
            idv_fraud_rejected: 2,
            time_range: (end_date.beginning_of_day - 90.days)..end_date,
          ),
        ],
      )
    end

    it 'renders a report with 30, 60, 90 day numbers' do
      # rubocop:disable Layout/LineLength
      expected_csv = [
        ['Metric', 'Trailing 30d', 'Trailing 60d', 'Trailing 90d'],
        ['Start Date', Date.new(2021, 12, 2), Date.new(2021, 11, 2), Date.new(2021, 10, 3)],
        ['End Date', Date.new(2022, 1, 1), Date.new(2022, 1, 1), Date.new(2022, 1, 1)],
        ['IDV Started', 4, 5, 6],
        ['Welcome Submitted', 3, 4, 5],
        ['Image Submitted', 2, 3, 4],
        ['Successfully Verified', 1, 2, 3],
        ['IDV Rejected (Non-Fraud)', 1, 1, 1],
        ['IDV Rejected (Fraud)', 0, 1, 2],
        ['Blanket Proofing Rate (IDV Started to Successfully Verified)', 1.0 / 4, 2.0 / 5, 3.0 / 6],
        ['Intent Proofing Rate (Welcome Submitted to Successfully Verified)', 1.0 / 3, 2.0 / 4, 3.0 / 5],
        ['Actual Proofing Rate (Image Submitted to Successfully Verified)', 1.0 / 2, 2.0 / 3, 3.0 / 4],
        ['Industry Proofing Rate (Verified minus IDV Rejected)', 1.0 / 2, 2.0 / 3, 3.0 / 4],
      ]
      # rubocop:enable Layout/LineLength

      aggregate_failures do
        report.as_csv.zip(expected_csv).each do |actual, expected|
          expect(actual).to eq(expected)
        end
      end
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
              (end_date.beginning_of_day - 30.days)..end_date,
              (end_date.beginning_of_day - 60.days)..end_date,
              (end_date.beginning_of_day - 90.days)..end_date,
            ],
          )

          expect(Reporting::IdentityVerificationReport).to have_received(:new).with(
            time_range: (end_date.beginning_of_day - 30.days)..end_date,
            issuers: nil,
            cloudwatch_client: report.cloudwatch_client,
          ).once

          expect(Reporting::IdentityVerificationReport).to have_received(:new).with(
            time_range: (end_date.beginning_of_day - 60.days)..(end_date.end_of_day - 30.days),
            issuers: nil,
            cloudwatch_client: report.cloudwatch_client,
          ).once

          expect(Reporting::IdentityVerificationReport).to have_received(:new).with(
            time_range: (end_date.beginning_of_day - 90.days)..(end_date.end_of_day - 60.days),
            issuers: nil,
            cloudwatch_client: report.cloudwatch_client,
          ).once
        end
      end
    end
  end
end
