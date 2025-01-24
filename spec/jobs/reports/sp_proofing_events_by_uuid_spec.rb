require 'rails_helper'

RSpec.describe Reports::SpProofingEventsByUuid do
  let(:report_date) { Date.new(2024, 12, 1).in_time_zone('UTC') }
  let(:issuers) { ['super:cool:test:issuer'] }
  let(:agency_abbreviation) { 'DOL' }

  before do
    allow(IdentityConfig.store).to receive(:s3_reports_enabled).and_return(true)
  end

  describe '#perform' do
    it 'gets a CSV from the report maker, saves it to S3, and sends email to team' do
      allow(IdentityConfig.store).to receive(:team_ada_email).and_return('ada@example.com')

      report = [
        ['UUID', 'Welcome Visited', 'Welcome Submitted'],
        ['123abc', true, true],
        ['456def', true, false],
      ]
      csv_report = CSV.generate do |csv|
        report.each { |row| csv << row }
      end
      emailable_reports = [
        Reporting::EmailableReport.new(
          title: 'DOL Proofing Events By UUID - 2024-12-01',
          table: report,
          filename: 'dol_proofing_events_by_uuid',
        ),
      ]

      report_maker = double(
        Reporting::SpProofingEventsByUuid,
        to_csv: csv_report,
        as_emailable_reports: emailable_reports,
      )

      allow(subject).to receive(:report_maker).and_return(report_maker)
      expect(subject).to receive(:save_report).with(
        'dol_proofing_events_by_uuid',
        csv_report,
        extension: 'csv',
      )

      expect(ReportMailer).to receive(:tables_report).once.with(
        email: IdentityConfig.store.team_ada_email,
        subject: 'DOL Proofing Events By UUID - 2024-12-01',
        reports: emailable_reports,
        message: anything,
        attachment_format: :csv,
      ).and_call_original

      subject.perform(report_date, issuers, agency_abbreviation)
    end

    it 'does not send report in email if the email field is empty' do
      allow(IdentityConfig.store).to receive(:team_ada_email).and_return('')

      report_maker = double(
        Reporting::SpProofingEventsByUuid,
        to_csv: 'I am a CSV, see',
        identity_verification_emailable_report: 'I am a report',
      )
      allow(subject).to receive(:report_maker).and_return(report_maker)
      expect(subject).to receive(:save_report).with(
        'dol_proofing_events_by_uuid',
        'I am a CSV, see',
        extension: 'csv',
      )

      expect(ReportMailer).to_not receive(:tables_report)

      subject.perform(report_date, issuers, agency_abbreviation)
    end
  end

  describe '#report_maker' do
    it 'is a identity verification report maker with the correct attributes' do
      subject.report_date = Date.new(2024, 12, 1)
      subject.issuers = ['super:cool:test:issuer']
      subject.agency_abbreviation = 'DOL'

      expect(subject.report_maker.time_range).to eq(Date.new(2024, 12, 1)..Date.new(2024, 12, 7))
      expect(subject.report_maker.issuers).to eq(['super:cool:test:issuer'])
      expect(subject.agency_abbreviation).to eq('DOL')
    end
  end
end
