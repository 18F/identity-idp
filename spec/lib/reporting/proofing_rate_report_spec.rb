require 'rails_helper'
require 'reporting/proofing_rate_report'

RSpec.describe Reporting::ProofingRateReport do
  let(:start_date) { Date.new(2022, 1, 1) }

  subject(:report) do
    Reporting::ProofingRateReport.new(start_date: start_date)
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
            time_range: (start_date - 30.days)..start_date,
          ),
          instance_double(
            'Reporting::IdentityVerificationReport',
            idv_started: 5,
            idv_doc_auth_welcome_submitted: 4,
            idv_doc_auth_image_vendor_submitted: 3,
            successfully_verified_users: 2,
            time_range: (start_date - 60.days)..start_date,
          ),
          instance_double(
            'Reporting::IdentityVerificationReport',
            idv_started: 6,
            idv_doc_auth_welcome_submitted: 5,
            idv_doc_auth_image_vendor_submitted: 4,
            successfully_verified_users: 3,
            time_range: (start_date - 90.days)..start_date,
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
        ['Blanket Proofing Rate (IDV Started to Successfully Verified)', 1.0 / 4, 2.0 / 5, 3.0 / 6],
        ['Intent Proofing Rate (Welcome Submitted to Successfully Verified)', 1.0 / 3, 2.0 / 4, 3.0 / 5],
        ['Actual Proofing Rate (Image Submitted to Successfully Verified)', 1.0 / 2, 2.0 / 3, 3.0 / 4],
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
    it 'calls IdentityVerificationReport correctly' do
      expect(Reporting::IdentityVerificationReport).to receive(:new).with(
        issuers: nil,
        time_range: (start_date - 30.days)..start_date,
      ).and_call_original
      expect(Reporting::IdentityVerificationReport).to receive(:new).with(
        issuers: nil,
        time_range: (start_date - 60.days)..start_date,
      ).and_call_original
      expect(Reporting::IdentityVerificationReport).to receive(:new).with(
        issuers: nil,
        time_range: (start_date - 90.days)..start_date,
      ).and_call_original

      expect(report.reports).to be_present
    end
  end
end
