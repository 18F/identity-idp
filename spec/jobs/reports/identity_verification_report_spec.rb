require 'rails_helper'

RSpec.describe Reports::IdentityVerificationReport do
  let(:report_date) { Date.new(2023, 12, 12).in_time_zone('UTC') }
  let(:team_ada_emails) { ['ada@example.com'] }

  before do
    allow(IdentityConfig.store).to receive(:s3_reports_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:team_ada_emails).and_return(team_ada_emails)
  end

  describe '#perform' do
    it 'gets a CSV from the report maker, saves it to S3, and sends email to team' do
      reports =
        Reporting::EmailableReport.new(
          title: 'Identity Verification Metrics',
          table: [
            ['Report Timeframe', '2023-12-10 00:00:00 UTC to 2023-12-10 23:59:59 UTC'],
            ['Report Generated', '2023-12-11'],
            ['Issuer', 'some:issuer'],
            ['Metric', '# of Users'],
            [],
            ['Started IdV Verification', '78'],
            ['Submitted welcome page', '75'],
            ['Images uploaded', '73'],
            [],
            ['Workflow completed', '72'],
            ['Workflow completed - Verified', '71'],
            ['Workflow completed - Total Pending', '33'],
            ['Workflow completed - GPO Pending', '23'],
            ['Workflow completed - In-Person Pending', '55'],
            ['Workflow completed - Fraud Review Pending', '34'],
            [],
            ['Successfully verified', '56'],
            ['Successfully verified - Inline', '55'],
            ['Successfully verified - GPO Code Entry', '25'],
            ['Successfully verified - In Person', '25'],
            ['Successfully verified - Passed Fraud Review', '15'],
          ],
          filename: 'identity_verification_metrics',
        )

      report_maker = double(
        Reporting::IdentityVerificationReport,
        to_csv: 'I am a CSV, see',
        identity_verification_emailable_report: reports,
      )
      allow(subject).to receive(:report_maker).and_return(report_maker)
      expect(subject).to receive(:save_report).with(
        'identity-verification-report',
        'I am a CSV, see',
        extension: 'csv',
      )

      expect(ReportMailer).to receive(:tables_report).once.with(
        email: IdentityConfig.store.team_ada_emails[0],
        subject: 'Daily Identity Verification Report - 2023-12-12',
        reports: anything,
        message: anything,
        attachment_format: :csv,
      ).and_call_original

      subject.perform(report_date)
    end
  end

  describe '#report_maker' do
    it 'is a identity verification report maker with the right time range' do
      report_date = Date.new(2023, 12, 25)

      subject.report_date = report_date

      expect(subject.report_maker.time_range).to eq(report_date.all_day)
    end
  end
end
