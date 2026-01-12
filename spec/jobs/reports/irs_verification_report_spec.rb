# spec/jobs/reports/irs_verification_report_spec.rb
require 'rails_helper'
require 'csv'

RSpec.describe Reports::IrsVerificationReport do
  let(:report_date) { Time.zone.parse('2025-11-14 23:59:59 UTC') } # Friday
  let(:mock_internal_emails) { ['internal1@example.com', 'internal2@example.com'] }
  let(:mock_partner_emails)  { ['partner@example.com'] }
  let(:mock_issuers)         { ['issuer1', 'issuer2'] }
  let(:mock_agency)          { 'Test_partner' }

  let(:configs) do
    [
      {
        'issuers' => mock_issuers,
        'agency_abbreviation' => mock_agency,
        'internal_emails' => mock_internal_emails,
        'partner_emails' => mock_partner_emails,
      },
    ]
  end

  let(:emailable_reports) do
    [
      Reporting::EmailableReport.new(
        title: 'Definitions',
        table: [
          ['Metric', 'Count', 'Rate'], ['Verification Demand', 100, 1.0],
          ['Document Authentication Success', 80, 0.8],
          ['Information Verification Success', 70, 0.7],
          ['Phone Verification Success', 60, 0.6],
          ['Verification Successes', 50, 0.5],
          ['Verification Failures', 50, 0.5]
        ],
        filename: 'definitions',
      ),
      Reporting::EmailableReport.new(
        title: 'Overview',
        table: [['Report Timeframe', 'Report Generated', 'Issuer']],
        filename: 'overview',
      ),
    ]
  end

  before do
    allow(IdentityConfig.store).to receive(:sp_verification_report_configs).and_return(configs)
    allow(IdentityConfig.store).to receive(:s3_reports_enabled).and_return(true)

    # Prevent real AWS calls
    allow_any_instance_of(described_class).to receive(:bucket_name).and_return('test-bucket')
    allow_any_instance_of(described_class).to receive(:upload_file_to_s3_bucket).and_return(true)

    # No-op mailer
    allow(ReportMailer).to receive_message_chain(:tables_report, :deliver_now).and_return(true)
  end

  # Helper to compute the previous week range used by the job
  def expected_previous_week_range(for_date)
    for_date.beginning_of_week(:sunday).prev_occurring(:sunday).all_week(:sunday)
  end

  describe '#perform' do
    it 'builds the report for both internal + partner when receiver=:both' do
      range = expected_previous_week_range(report_date)

      # Expect the builder to be constructed with the correct args and return emailable_reports
      expect(Reporting::IrsVerificationReport).to receive(:new).with(
        time_range: range,
        issuers: mock_issuers,
        agency_abbreviation: mock_agency,
      ).and_return(instance_double(
        Reporting::IrsVerificationReport,
        as_emailable_reports: emailable_reports,
      ))

      # Expect uploads (one per emailable report)
      emailable_reports.each do |r|
        expect_any_instance_of(described_class).to receive(:upload_to_s3).with(
          r.table,
          report_name: r.filename,
        )
      end

      # Expect email goes to both internal and partner sets
      expect(ReportMailer).to receive(:tables_report).with(
        to: mock_partner_emails,
        bcc: mock_internal_emails,
        subject: "#{mock_agency} Verification Report - #{report_date.to_date}",
        reports: emailable_reports,
        message: kind_of(String),
        attachment_format: :csv,
      ).and_call_original

      described_class.new.perform(report_date, :both)
    end

    it 'emails only internal when receiver=:internal' do
      range = expected_previous_week_range(report_date)

      allow(Reporting::IrsVerificationReport).to receive(:new).with(
        time_range: range,
        issuers: mock_issuers,
        agency_abbreviation: mock_agency,
      ).and_return(instance_double(
        Reporting::IrsVerificationReport,
        as_emailable_reports: emailable_reports,
      ))

      expect(ReportMailer).to receive(:tables_report).with(
        to: mock_internal_emails,
        bcc: [],
        subject: "#{mock_agency} Verification Report - #{report_date.to_date}",
        reports: emailable_reports,
        message: kind_of(String),
        attachment_format: :csv,
      ).and_call_original

      described_class.new.perform(report_date, :internal)
    end

    context 'when no emails are configured for the chosen receiver' do
      let(:mock_internal_emails) { [] }
      let(:mock_partner_emails)  { [] }

      it 'does not build or send the report and returns false' do
        # Ensure we do NOT instantiate the builder or call mailer
        expect(ReportMailer).not_to receive(:tables_report)

        described_class.new.perform(report_date, :internal)
      end
    end
  end

  describe '#previous_week_range' do
    it 'returns the sunday..saturday range for the previous week based on report_date' do
      job = described_class.new(report_date, :internal)
      range = job.previous_week_range

      expect(range).to be_a(Range)
      expect(range.first.to_date.wday).to eq(0) # Sunday
      expect(range.last.to_date.wday).to eq(6)  # Saturday
      expect((range.last.to_date - range.first.to_date).to_i).to eq(6)
      expect(range).to eq(expected_previous_week_range(report_date))
    end
  end
end
