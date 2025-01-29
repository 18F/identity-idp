require 'rails_helper'
require 'reporting/sp_idv_weekly_dropoff_report'

RSpec.describe Reporting::SpIdvWeeklyDropoffReport do
  let(:issuers) { ['super:cool:test:issuer'] }
  let(:agency_abbreviation) { 'ABC' }
  let(:time_range) { Date.new(2024, 12, 1)..Date.new(2024, 12, 14) }

  let(:cloudwatch_results) do
    [
      [
        {
          'ial' => '1',
          'getting_started_dropoff' => '0.01',
          'document_capture_started_dropoff' => '0.02',
          'document_captured_dropoff' => '0.03',
          'selfie_captured_dropoff' => '0',
          'document_authentication_passed_dropoff' => '0.04',
          'ssn_dropoff' => '0.05',
          'verify_info_submitted_dropoff' => '0.06',
          'verify_info_passed_dropoff' => '0.07',
          'phone_submitted_dropoff' => '0.08',
          'phone_passed_dropoff' => '0.09',
          'enter_password_dropoff' => '0.10',
          'personal_key_dropoff' => '0.11',
          'agency_handoff_dropoff' => '0.12',
          'document_authentication_failure_numerator' => '100',
          'document_authentication_failure_denominator' => '200',
          'selfie_check_failure_numerator' => '0',
          'selfie_check_failure_denominator' => '0',
          'aamva_check_failure_numerator' => '300',
          'aamva_check_failure_denominator' => '400',
          'verified_inline_count' => '500',
          'fraud_review_passed_count' => '600',
          'fraud_review_rejected_count' => '700',
        },
      ],
      [
        {
          'ial' => '1',
          'verify_by_mail_dropoff' => '0.01',
          'fraud_review_dropoff' => '0.02',
        },
      ],
      [
        {
          'ial' => '1',
          'getting_started_dropoff' => '0.13',
          'document_capture_started_dropoff' => '0.14',
          'document_captured_dropoff' => '0.15',
          'selfie_captured_dropoff' => '0',
          'document_authentication_passed_dropoff' => '0.16',
          'ssn_dropoff' => '0.17',
          'verify_info_submitted_dropoff' => '0.18',
          'verify_info_passed_dropoff' => '0.19',
          'phone_submitted_dropoff' => '0.20',
          'phone_passed_dropoff' => '0.21',
          'enter_password_dropoff' => '0.22',
          'personal_key_dropoff' => '0.23',
          'agency_handoff_dropoff' => '0.24',
          'document_authentication_failure_numerator' => '800',
          'document_authentication_failure_denominator' => '900',
          'selfie_check_failure_numerator' => '0',
          'selfie_check_failure_denominator' => '0',
          'aamva_check_failure_numerator' => '1000',
          'aamva_check_failure_denominator' => '1100',
          'verified_inline_count' => '1200',
          'fraud_review_passed_count' => '1300',
          'fraud_review_rejected_count' => '1400',
          'gpo_passed_count' => '1500',
        },
        {
          'ial' => '2',
          'getting_started_dropoff' => '0.25',
          'document_capture_started_dropoff' => '0.26',
          'document_captured_dropoff' => '0.27',
          'selfie_captured_dropoff' => '0.29',
          'document_authentication_passed_dropoff' => '0.30',
          'ssn_dropoff' => '0.31',
          'verify_info_submitted_dropoff' => '0.32',
          'verify_info_passed_dropoff' => '0.33',
          'phone_submitted_dropoff' => '0.34',
          'phone_passed_dropoff' => '0.35',
          'enter_password_dropoff' => '0.36',
          'personal_key_dropoff' => '0.37',
          'agency_handoff_dropoff' => '0.38',
          'document_authentication_failure_numerator' => '1600',
          'document_authentication_failure_denominator' => '1700',
          'selfie_check_failure_numerator' => '1800',
          'selfie_check_failure_denominator' => '1900',
          'aamva_check_failure_numerator' => '2000',
          'aamva_check_failure_denominator' => '2100',
          'verified_inline_count' => '2200',
          'fraud_review_passed_count' => '2300',
          'fraud_review_rejected_count' => '2400',
          'gpo_passed_count' => '0',
        },
      ],
      [
        {
          'ial' => '1',
          'verify_by_mail_dropoff' => '0.03',
          'fraud_review_dropoff' => '0.04',
        },
        {
          'ial' => '2',
          'verify_by_mail_dropoff' => '0',
          'fraud_review_dropoff' => '0.5',
        },
      ],
    ]
  end

  let(:expected_result) do
    [
      ['', '2024-12-01 - 2024-12-07', '2024-12-08 - 2024-12-14'],
      ['Overview'],
      ['# of verified users'],
      ['    - IAL2', '0', '4500'],
      ['    - Non-IAL2', '1100', '4000'],
      ['# of contact center cases'],
      ['Fraud Checks'],
      ['% of users that failed document authentication check', '50.0%', '92.31%'],
      ['% of users that failed facial match check (Only for IAL2)', '0.0%', '94.74%'],
      ['% of users that failed AAMVA attribute match check', '75.0%', '93.75%'],
      ['# of users that failed LG-99 fraud review', '700', '3800'],
      ['User Experience'],
      ['# of verified users via verify-by-mail process (Only for non-IAL2)', '0', '1500'],
      ['# of verified users via fraud redress process', '600', '3600'],
      ['# of verified users via in-person proofing (Not currently enabled)', '0', '0'],
      ['Funnel Analysis'],
      ['% drop-off at Workflow Started'],
      ['    - IAL2', '0.0%', '25.0%'],
      ['    - Non-IAL2', '1.0%', '13.0%'],
      ['% drop-off at Document Capture Started'],
      ['    - IAL2', '0.0%', '26.0%'],
      ['    - Non-IAL2', '2.0%', '14.0%'],
      ['% drop-off at Document Captured'],
      ['    - IAL2', '0.0%', '27.0%'],
      ['    - Non-IAL2', '3.0%', '15.0%'],
      ['% drop-off at Selfie Captured'],
      ['    - IAL2', '0.0%', '29.0%'],
      ['% drop-off at Document Authentication Passed'],
      ['    - IAL2 (with Facial Match)', '0.0%', '30.0%'],
      ['    - Non-IAL2', '4.0%', '16.0%'],
      ['% drop-off at SSN Submitted'],
      ['    - IAL2', '0.0%', '31.0%'],
      ['    - Non-IAL2', '5.0%', '17.0%'],
      ['% drop-off at Personal Information Submitted'],
      ['    - IAL2', '0.0%', '32.0%'],
      ['    - Non-IAL2', '6.0%', '18.0%'],
      ['% drop-off at Personal Information Verified'],
      ['    - IAL2', '0.0%', '33.0%'],
      ['    - Non-IAL2', '7.0%', '19.0%'],
      ['% drop-off at Phone Submitted'],
      ['    - IAL2', '0.0%', '34.0%'],
      ['    - Non-IAL2', '8.0%', '20.0%'],
      ['% drop-off at Phone Verified'],
      ['    - IAL2', '0.0%', '35.0%'],
      ['    - Non-IAL2', '9.0%', '21.0%'],
      ['% drop-off at Online Wofklow Completed'],
      ['    - IAL2', '0.0%', '36.0%'],
      ['    - Non-IAL2', '10.0%', '22.0%'],
      ['% drop-off at Verified for In-Band Users'],
      ['    - IAL2', '0.0%', '0.0%'],
      ['    - Non-IAL2', '0.0%', '0.0%'],
      ['% drop-off at Verified for Verify-by-mail Users'],
      ['    - Non-IAL2', '1.0%', '3.0%'],
      ['% drop-off at Verified for Fraud Review Users'],
      ['    - IAL2', '0.0%', '50.0%'],
      ['    - Non-IAL2', '2.0%', '4.0%'],
      ['% drop-off at Personal Key Saved'],
      ['    - IAL2', '0.0%', '37.0%'],
      ['    - Non-IAL2', '11.0%', '23.0%'],
      ['% drop-off at Agency Handoff Submitted'],
      ['    - IAL2', '0.0%', '38.0%'],
      ['    - Non-IAL2', '12.0%', '24.0%'],
    ]
  end

  before do
    stub_multiple_cloudwatch_logs(*cloudwatch_results)
  end

  subject(:report) { described_class.new(issuers:, agency_abbreviation:, time_range:) }

  describe '#as_csv' do
    it 'queries cloudwatch and formats a report' do
      expect(report.as_csv).to eq(expected_result)
    end
  end

  describe '#to_csv' do
    it 'returns a CSV report' do
      csv = CSV.parse(report.to_csv, headers: false)

      aggregate_failures do
        csv.map(&:to_a).zip(expected_result).each do |actual, expected|
          expect(actual).to eq(expected)
        end
      end
    end
  end

  describe 'as_emailable_report' do
    it 'returns an array with an emailable report' do
      expect(report.as_emailable_reports).to eq(
        [
          Reporting::EmailableReport.new(
            title: 'ABC IdV Dropoff Report',
            table: expected_result,
            filename: 'abc_idv_dropoff_report',
          ),
        ],
      )
    end
  end
end
