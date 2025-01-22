require 'rails_helper'
require 'reporting/sp_proofing_events_by_uuid'

RSpec.describe Reporting::SpProofingEventsByUuid do
  let(:issuer) { 'super_cool_test_issuer' }
  let(:agency_abbreviation) { 'DOL' }
  let(:agency) { Agency.find_by(abbreviation: agency_abbreviation) }

  let(:time_range) { Date.new(2024, 12, 1).all_week(:sunday) }

  let(:deleted_user_uuid) { 'deleted_user_test' }
  let(:non_agency_user_uuid) { 'non_agency_user_test' }
  let(:agency_user_login_uuid) { 'agency_user_login_uuid_test' }
  let(:agency_user_agency_uuid) { 'agency_user_agency_uuid_test' }

  let(:cloudwatch_logs) do
    [
      { 'login_uuid' => deleted_user_uuid, 'workflow_started' => '1' },
      { 'login_uuid' => non_agency_user_uuid, 'workflow_started' => '1' },
      { 'login_uuid' => agency_user_login_uuid, 'workflow_started' => '1' },
    ]
  end

  before do
    create(:user, uuid: non_agency_user_uuid)
    agency_user = create(:user, uuid: agency_user_login_uuid)
    create(:agency_identity, user: agency_user, uuid: agency_user_agency_uuid)

    stub_cloudwatch_logs(cloudwatch_logs)
  end

  subject(:report) do
    Reporting::SpProofingEventsByUuid.new(
      issuers: Array(issuer), agency_abbreviation:, time_range:,
    )
  end

  describe 'as_csv' do
    it 'renders a CSV report with converted UUIDs' do
      expected_csv = [
        ['Date Range', '2024-12-01 - 2024-12-07'],
        [
          'UUID',
          'Workflow Started',
          'Documnet Capture Started',
          'Document Captured',
          'Selfie Captured',
          'Document Authentication Passed',
          'SSN Submitted',
          'Personal Information Submitted',
          'Personal Information Verified',
          'Phone Submitted',
          'Phone Verified',
          'Verification Workflow Complete',
          'Identity Verified for In-Band Users',
          'Identity Verified for Verify-By-Mail Users',
          'Identity Verified for Fraud Review Users',
          'Out-of-Band Verification Pending Seconds',
          'Agency Handoff Visited',
          'Agency Handoff Submitted',
        ],
        [
          agency_user_login_uuid,
          true,
          false,
          false,
          false,
          false,
          false,
          false,
          false,
          false,
          false,
          false,
          false,
          false,
          false,
          0,
          false,
          false,
        ],
      ]
      aggregate_failures do
        report.as_csv.zip(expected_csv).each do |actual, expected|
          expect(actual).to eq(expected)
        end
      end
    end
  end

  describe '#to_csv' do
    it 'generates a csv' do
      csv = CSV.parse(report.to_csv, headers: false)

      expected_csv = [
        ['Date Range', '2024-12-01 - 2024-12-07'],
        [
          'UUID',
          'Workflow Started',
          'Documnet Capture Started',
          'Document Captured',
          'Selfie Captured',
          'Document Authentication Passed',
          'SSN Submitted',
          'Personal Information Submitted',
          'Personal Information Verified',
          'Phone Submitted',
          'Phone Verified',
          'Verification Workflow Complete',
          'Identity Verified for In-Band Users',
          'Identity Verified for Verify-By-Mail Users',
          'Identity Verified for Fraud Review Users',
          'Out-of-Band Verification Pending Seconds',
          'Agency Handoff Visited',
          'Agency Handoff Submitted',
        ],
        [
          agency_user_login_uuid,
          'true',
          'false',
          'false',
          'false',
          'false',
          'false',
          'false',
          'false',
          'false',
          'false',
          'false',
          'false',
          'false',
          'false',
          '0',
          'false',
          'false',
        ],
      ]

      aggregate_failures do
        csv.map(&:to_a).zip(expected_csv).each do |actual, expected|
          expect(actual).to eq(expected)
        end
      end
    end
  end

  describe '#as_emailable_reports' do
    it 'returns an emailable report'
  end
end
