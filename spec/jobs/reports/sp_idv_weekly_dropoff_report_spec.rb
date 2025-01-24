require 'rails_helper'

RSpec.describe Reports::SpIdvWeeklyDropoffReport do
  let(:report_date) { Date.new(2024, 12, 16).in_time_zone('UTC') }
  let(:agency_abbreviation) { 'ABC' }
  let(:report_emails) { ['test@example.com'] }
  let(:sp_idv_weekly_dropoff_report_configs) do
    [
      {
        'issuers' => ['super:cool:test:issuer'],
        'report_start_date' => '2024-12-01',
        'agency_abbreviation' => 'ABC',
        'emails' => report_emails,
      },
    ]
  end

  before do
    allow(IdentityConfig.store).to receive(:s3_reports_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:sp_idv_weekly_dropoff_report_configs).and_return(
      sp_idv_weekly_dropoff_report_configs,
    )
  end

  describe '#perform' do
    it 'gets a CSV from the report maker, saves it to S3, and sends email to team' do
      allow(IdentityConfig.store).to receive(:team_ada_email).and_return('ada@example.com')

      report = [
        ['Label'],
        ['Useful dropoff info', '80%', '90%'],
        ['Other dropoff info', '70%', '60%'],
      ]
      csv_report = CSV.generate do |csv|
        report.each { |row| csv << row }
      end
      emailable_reports = [
        Reporting::EmailableReport.new(
          title: 'ABC IdV Dropoff Report - 2024-12-16',
          table: report,
          filename: 'abc_idv_dropoff_report',
        ),
      ]

      report_maker = double(
        Reporting::SpIdvWeeklyDropoffReport,
        to_csv: csv_report,
        as_emailable_reports: emailable_reports,
      )

      allow(subject).to receive(:build_report_maker).with(
        issuers: ['super:cool:test:issuer'],
        agency_abbreviation: 'ABC',
        time_range: Date.new(2024, 12, 1)..Date.new(2024, 12, 14),
      ).and_return(report_maker)

      expect(subject).to receive(:save_report).with(
        'abc_idv_dropoff_report',
        csv_report,
        extension: 'csv',
      )

      expect(ReportMailer).to receive(:tables_report).once.with(
        email: 'test@example.com',
        subject: 'ABC IdV Dropoff Report - 2024-12-16',
        reports: emailable_reports,
        message: anything,
        attachment_format: :csv,
      ).and_call_original

      subject.perform(report_date)
    end

    context 'with no emails configured' do
      let(:report_emails) { [] }

      it 'does not send the report in email' do
        report_maker = double(
          Reporting::SpIdvWeeklyDropoffReport,
          to_csv: 'I am a CSV, see',
          identity_verification_emailable_report: 'I am a report',
        )
        allow(subject).to receive(:build_report_maker).and_return(report_maker)
        expect(subject).to receive(:save_report).with(
          'abc_idv_dropoff_report',
          'I am a CSV, see',
          extension: 'csv',
        )

        expect(ReportMailer).to_not receive(:tables_report)

        subject.perform(report_date)
      end
    end
  end
end
