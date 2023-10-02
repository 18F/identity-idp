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
        'emails' => [email]
      }
    ]
  end

  before do
    allow(IdentityConfig.store).to receive(:s3_reports_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:weekly_auth_funnel_report_config).and_return(report_configs)
  end

  describe '#perform' do
    let(:report_maker) { double(Reporting::AuthenticationReport, to_csv: 'I am a CSV') }
    before do
      expect(Reporting::AuthenticationReport).to receive(:new).with(
        issuers:,
        time_range: report_date.all_week
        ) { report_maker }

      allow(ReportMailer).to receive(:authentication_report).and_call_original
    end

    it 'emails the csv' do
      expect(ReportMailer).to receive(:authentication_report).with(
        email:,
        name:,
        issuers:,
        data: 'I am a CSV'
      )
      subject.perform(report_date)
    end
  end

  describe '#report_maker' do
    it 'is a identity verification report maker with the right time range' do
      subject.report_date = report_date

      expect(subject.report_maker(issuers).time_range).to eq(report_date.all_week)
    end
  end
end
