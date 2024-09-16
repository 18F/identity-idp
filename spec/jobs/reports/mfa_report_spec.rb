require 'rails_helper'

RSpec.describe Reports::MfaReport do
  let(:issuer) { 'issuer1' }
  let(:issuers) { [issuer] }
  let(:report_date) { Date.new(2023, 12, 01) }
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
    allow(IdentityConfig.store).to receive(:mfa_report_config) { report_configs }
  end

  describe '#perform' do
    let(:reports) do
        [
            Reporting::EmailableReport.new(
              title: 'Overview',
              table: [            
                ['Report Timeframe', '2023-11-01 00:00:00 UTC to 2023-11-30 23:59:59 UTC'],
                ['Report Generated', '2023-12-01'],
                ['Issuer', 'issuer1'],
              ]
            ),
            Reporting::EmailableReport.new(
              title: 'Multi Factor Authentication Metrics',
              table: [
                ['Multi Factor Authentication (MFA) method', 'Number of successful sign-ins'],
                ['SMS', 'sms'],
                ['Voice', 'voice'],
                ['Security key', 'webauthn'],
                ['Face or touch unlock', 'face/touch'],
                ['PIV/CAC', 'piv_cac'],
                ['Authentication app', 'totp'],
                ['Backup codes', 'backup_code'],
                ['Personal key', 'personal_key'],
                ['Total number of phishing resistant methods', 'phishing_resistant'],
              ]
            ),
        ]
    end

    let(:monthly_report) { double(Reporting::MfaReport, as_emailable_reports: reports) }

    before do
      expect(Reporting::MfaReport).to receive(:new).with(
        issuers:,
        time_range: report_date.all_month,
      ) { monthly_report }

      allow(ReportMailer).to receive(:tables_report).and_call_original
    end

    it 'emails the csv' do
      expect(ReportMailer).to receive(:tables_report).with(
        email:,
        subject: "Monthly MFA Report - #{report_date}",
        message: "Report: mfa-report #{report_date}",
        reports:,
        attachment_format: :csv,
      )

      subject.perform(report_date)
    end
  end
end
