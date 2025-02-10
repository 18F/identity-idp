require 'rails_helper'

RSpec.describe Reports::MfaReport do
  let(:issuer) { 'issuer1' }
  let(:issuers) { [issuer] }
  let(:report_date) { Date.new(2023, 12, 0o1).in_time_zone('UTC') }
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
    let(:reports) { double('emailable_reports').as_null_object }

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

  describe 'with empty logs' do
    before do
      stub_cloudwatch_logs([])
    end

    it 'sends an email with at least 1 attachment' do
      subject.perform(report_date)
      sent_mail = ActionMailer::Base.deliveries.last
      expect(sent_mail.parts.attachments.count).to be >= 1
    end
  end
end
