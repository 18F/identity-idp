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
          ['Some', 'String'],
          ['a', 'b'],
          ['c', 'd'],
        ],
        [
          { float_as_percent: true, title: 'Custom Table 2' },
          ['Float', 'Int', 'Float'],
          ['Row 1', 1, 0.5],
          ['Row 2', 1, 1.5],
        ],
        [
          { float_as_percent: false, title: 'Custom Table 3' },
          ['Float As Percent', 'Gigantic Int', 'Float'],
          ['Row 1', 100_000_000, 1.0],
          ['Row 2', 123_456_789, 1.5],
        ],
      ]
    end

    let(:weekly_report) { double(Reporting::AuthenticationReport, as_csv: tables) }

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
      )

      subject.perform(report_date)
    end
  end
end
