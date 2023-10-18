require 'rails_helper'

RSpec.describe Reports::AuthenticationReport do
  let(:issuer) { 'issuer1' }
  let(:issuers) { [issuer] }
  let(:report_date) { Date.new(2023, 12, 25) }
  let(:email)  { 'partner.name@example.com' }
  let(:name) { 'Partner Name' }

  let(:report_configs) do
    [
      {
        'name' => name,
        'issuers' => issuers,
        'emails' => [email],
      },
    ]
  end

  before do
    allow(IdentityConfig.store).to receive(:s3_reports_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:weekly_auth_funnel_report_config) { report_configs }
  end

  describe '#perform' do
    let(:tables) do
      [
        [
          { title: 'Overview' },
          ['Report Timeframe', '2023-10-01 00:00:00 UTC to 2023-10-01 23:59:59 UTC'],
          ['Report Generated', '2023-10-02'],
          ['Issuer', 'some:issuer'],
          ['Total # of IAL1 Users', '75'],
        ],
        [
          { title: 'Authentication Metrics Report' },
          ['Metric', 'Number of accounts', '% of total from start'],
          ['New Users Started IAL1 Verification', '100', '100%'],
          ['New Users Completed IAL1 Password Setup', '85', '85%'],
          ['New Users Completed IAL1 MFA', '80', '80%'],
          ['New IAL1 Users Consented to Partner', '75', '75%'],
          ['AAL2 Authentication Requests from Partner', '12', '12%'],
          ['AAL2 Authenticated Requests', '50', '50%'],
        ],
      ]
    end

    let(:weekly_report) { double(Reporting::AuthenticationReport, as_tables_with_options: tables) }

    before do
      expect(Reporting::AuthenticationReport).to receive(:new).with(
        issuers:,
        time_range: report_date.all_week,
      ) { weekly_report }

      allow(ReportMailer).to receive(:tables_report).and_call_original
    end

    it 'emails the csv' do
      expect(ReportMailer).to receive(:tables_report).with(
        email:,
        subject: "Weekly Authentication Report - #{report_date}",
        message: "Report: authentication-report #{report_date}",
        tables:,
        attachment_format: :csv,
      )

      subject.perform(report_date)
    end
  end
end
