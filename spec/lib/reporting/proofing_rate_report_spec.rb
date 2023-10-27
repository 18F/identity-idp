require 'rails_helper'
require 'reporting/proofing_rate_report'

RSpec.describe Reporting::ProofingRateReport do
  let(:end_date) { Date.new(2022, 1, 1) }

  subject(:report) do
    Reporting::ProofingRateReport.new(end_date: end_date)
  end

  describe '#as_csv' do
    before do
      allow(report).to receive(:reports).and_return(
        [
          instance_double(
            'Reporting::IdentityVerificationReport',
            idv_started: 4,
            idv_doc_auth_welcome_submitted: 3,
            idv_doc_auth_image_vendor_submitted: 2,
            successfully_verified_users: 1,
            idv_doc_auth_rejected: 1,
            time_range: (end_date - 30.days)..end_date,
          ),
          instance_double(
            'Reporting::IdentityVerificationReport',
            idv_started: 5,
            idv_doc_auth_welcome_submitted: 4,
            idv_doc_auth_image_vendor_submitted: 3,
            successfully_verified_users: 2,
            idv_doc_auth_rejected: 1,
            time_range: (end_date - 60.days)..end_date,
          ),
          instance_double(
            'Reporting::IdentityVerificationReport',
            idv_started: 6,
            idv_doc_auth_welcome_submitted: 5,
            idv_doc_auth_image_vendor_submitted: 4,
            successfully_verified_users: 3,
            idv_doc_auth_rejected: 1,
            time_range: (end_date - 90.days)..end_date,
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
        ['IDV Rejected', 1, 1, 1],
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
  end

  describe '#reports' do
    before do
      stub_const('Reporting::CloudwatchClient::DEFAULT_WAIT_DURATION', 0)

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

    it 'calls IdentityVerificationReport with separate slices, but merges them' do
      allow(Reporting::IdentityVerificationReport).to receive(:new).and_call_original

      expect(report.reports.map(&:time_range)).to eq(
        [
          (end_date - 30.days)..end_date,
          (end_date - 60.days)..end_date,
          (end_date - 90.days)..end_date,
        ],
      )

      expect(Reporting::IdentityVerificationReport).to have_received(:new).with(
        time_range: (end_date - 30.days)..end_date,
        issuers: nil,
        cloudwatch_client: report.cloudwatch_client,
      ).once

      expect(Reporting::IdentityVerificationReport).to have_received(:new).with(
        time_range: (end_date - 60.days)..(end_date - 30.days),
        issuers: nil,
        cloudwatch_client: report.cloudwatch_client,
      ).once

      expect(Reporting::IdentityVerificationReport).to have_received(:new).with(
        time_range: (end_date - 90.days)..(end_date - 60.days),
        issuers: nil,
        cloudwatch_client: report.cloudwatch_client,
      ).once
    end
  end
end
