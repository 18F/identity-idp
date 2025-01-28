require 'rails_helper'
require 'reporting/sp_proofing_events_by_uuid'

RSpec.describe Reporting::SpProofingEventsByUuid do
  let(:issuer) { 'super:cool:test:issuer' }
  let(:agency_abbreviation) { 'DOL' }
  let(:agency) { Agency.find_by(abbreviation: agency_abbreviation) }

  let(:time_range) { Date.new(2024, 12, 1).all_week(:sunday) }

  let(:deleted_user_uuid) { 'deleted_user_test' }
  let(:non_agency_user_uuid) { 'non_agency_user_test' }
  let(:agency_user_login_uuid) { 'agency_user_login_uuid_test' }
  let(:agency_user_agency_uuid) { 'agency_user_agency_uuid_test' }

  let(:cloudwatch_logs) do
    [
      {
        'login_uuid' => deleted_user_uuid,
        'workflow_started' => '1',
        'first_event' => '1.735275676123E12',
      },
      {
        'login_uuid' => non_agency_user_uuid,
        'workflow_started' => '1',
        'first_event' => '1.735275676456E12',
      },
      {
        'login_uuid' => agency_user_login_uuid,
        'workflow_started' => '1',
        'first_event' => '1.735275676789E12',
      },
    ]
  end

  let(:expect_csv_result) do
    [
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
        agency_user_agency_uuid,
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
  end

  before do
    create(:user, uuid: non_agency_user_uuid)
    agency_user = create(:user, uuid: agency_user_login_uuid)
    create(:agency_identity, user: agency_user, agency:, uuid: agency_user_agency_uuid)

    stub_cloudwatch_logs(cloudwatch_logs)
  end

  subject(:report) do
    Reporting::SpProofingEventsByUuid.new(
      issuers: Array(issuer), agency_abbreviation:, time_range:,
    )
  end

  describe '#as_csv' do
    it 'renders a CSV report with converted UUIDs' do
      aggregate_failures do
        expect_csv_result.zip(report.as_csv).each do |actual, expected|
          expect(actual).to eq(expected)
        end
      end
    end
  end

  describe '#to_csv' do
    it 'generates a csv' do
      csv = CSV.parse(report.to_csv, headers: false)

      stringified_csv = expect_csv_result.map { |row| row.map(&:to_s) }

      aggregate_failures do
        csv.map(&:to_a).zip(stringified_csv).each do |actual, expected|
          expect(actual).to eq(expected)
        end
      end
    end
  end

  describe '#as_emailable_reports' do
    it 'returns an array with an emailable report' do
      expect(report.as_emailable_reports).to eq(
        [
          Reporting::EmailableReport.new(
            title: 'DOL Proofing Events By UUID',
            table: expect_csv_result,
            filename: 'dol_proofing_events_by_uuid',
          ),
        ],
      )
    end
  end

  describe '#data' do
    it 'fetches additional results if 10k results are returned' do
      cloudwatch_client = double(Reporting::CloudwatchClient)
      expect(cloudwatch_client).to receive(:fetch).ordered do |args|
        expect(args[:query]).to_not include('| filter first_event')
        [
          {
            'login_uuid' => agency_user_login_uuid,
            'workflow_started' => '1',
            'first_event' => '1.123456E12',
          },
        ] * 10000
      end
      expect(cloudwatch_client).to receive(:fetch).ordered do |args|
        expect(args[:query]).to include('| filter first_event > 1.123456E12')
        [
          {
            'login_uuid' => agency_user_login_uuid,
            'workflow_started' => '1',
            'first_event' => '1.123456E12',
          },
        ]
      end
      allow(report).to receive(:cloudwatch_client).and_return(cloudwatch_client)

      expect(report.data.count).to eq(10_001)
    end
  end
end
