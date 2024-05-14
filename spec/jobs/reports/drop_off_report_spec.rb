require 'rails_helper'

RSpec.describe Reports::DropOffReport do
  let(:report_date) { Date.new(2023, 12, 12).in_time_zone('UTC') }
  let(:report_config) do
    '[{"emails":["ursula@example.com"],
       "issuers":"urn:gov:gsa:openidconnect.profiles:sp:sso:agency_name:app_name"}]'
  end

  before do
    allow(IdentityConfig.store).to receive(:drop_off_report_config).and_return(report_config)
  end

  describe '#perform' do
    it 'gets a CSV from the report maker, and sends email' do
      reports = Reporting::EmailableReport.new(
        title: 'Drop Off Report',
        table: [
          ['Term', 'Description', 'Definition', 'Calculated'],
          ['1', '2', '3', '4'],
        ],
        filename: 'drop_off_report',
      )

      report_maker = double(
        Reporting::DropOffReport,
        to_csvs: 'I am a CSV, see',
        as_emailable_reports: reports,
      )

      allow(subject).to receive(:report_maker).and_return(report_maker)

      expect(ReportMailer).to receive(:tables_report).once.with(
        email: 'ursula@example.com',
        subject: 'Drop Off Report - 2023-12-12',
        reports: anything,
        message: anything,
        attachment_format: :csv,
      ).and_call_original

      subject.perform(report_date)
    end
  end

  describe '#report_maker' do
    it 'is a drop off report maker with the right time range' do
      report_date = Date.new(2023, 12, 25).in_time_zone('UTC')

      subject.report_date = report_date

      expect(subject.report_maker([]).time_range).to eq(report_date.all_month)
    end
  end
end
