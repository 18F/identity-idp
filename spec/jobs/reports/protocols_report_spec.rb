require 'rails_helper'

RSpec.describe Reports::ProtocolsReport do
  let(:report_date) { Date.new(2024, 7, 5).in_time_zone('UTC') }
  let(:email) { 'team@example.com' }

  let(:report_configs) do
    [
      {
        'emails' => [email],
      },
    ]
  end

  before do
    allow(IdentityConfig.store).to receive(:s3_reports_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:protocols_report_config) { report_configs }
  end

  describe '#perform' do
    it 'sends emailable reports to the ReportMailer' do
      emailable_reports = double('emailable_reports').as_null_object
      protocols_report = instance_double(
        Reporting::ProtocolsReport,
        as_emailable_reports: emailable_reports,
      )

      expect(Reporting::ProtocolsReport).to receive(:new).with(
        issuers: nil,
        time_range: report_date.all_week,
      ) { protocols_report }
      expect(ReportMailer).to receive(:tables_report).with(
        email:,
        subject: "Weekly Protocols Report - #{report_date}",
        message: "Report: protocols-report #{report_date}",
        reports: emailable_reports,
        attachment_format: :csv,
      ).and_call_original

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
