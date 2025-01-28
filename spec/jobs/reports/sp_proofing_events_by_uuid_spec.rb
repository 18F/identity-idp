require 'rails_helper'

RSpec.describe Reports::SpProofingEventsByUuid do
  let(:report_date) { Date.new(2024, 12, 9) }
  let(:agency_abbreviation) { 'ABC' }
  let(:report_emails) { ['test@example.com'] }
  let(:issuers) { ['super:cool:test:issuer'] }
  let(:sp_proofing_events_by_uuid_report_configs) do
    [
      {
        'issuers' => issuers,
        'agency_abbreviation' => 'ABC',
        'emails' => report_emails,
      },
    ]
  end

  before do
    allow(IdentityConfig.store).to receive(:s3_reports_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(
      :sp_proofing_events_by_uuid_report_configs,
    ).and_return(
      sp_proofing_events_by_uuid_report_configs,
    )
  end

  describe '#perform' do
    it 'gets a CSV from the report maker, saves it to S3, and sends email to team' do
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

      allow(subject).to receive(:build_report_maker).with(
        issuers: issuers,
        agency_abbreviation: 'ABC',
        time_range: Date.new(2024, 12, 1)..Date.new(2024, 12, 7),
      ).and_return(report_maker)
      expect(subject).to receive(:save_report).with(
        'abc_proofing_events_by_uuid',
        csv_report,
        extension: 'csv',
      )

      expect(ReportMailer).to receive(:tables_report).once.with(
        email: 'test@example.com',
        subject: 'ABC Proofing Events By UUID - 2024-12-09',
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
          Reporting::SpProofingEventsByUuid,
          to_csv: 'I am a CSV, see',
          identity_verification_emailable_report: 'I am a report',
        )
        allow(subject).to receive(:build_report_maker).with(
          issuers: issuers,
          agency_abbreviation: 'ABC',
          time_range: Date.new(2024, 12, 1)..Date.new(2024, 12, 7),
        ).and_return(report_maker)
        expect(subject).to receive(:save_report).with(
          'abc_proofing_events_by_uuid',
          'I am a CSV, see',
          extension: 'csv',
        )

        expect(ReportMailer).to_not receive(:tables_report)

        subject.perform(report_date)
      end
    end
  end

  describe '#build_report_maker' do
    it 'is a identity verification report maker with the correct attributes' do
      report_maker = subject.build_report_maker(
        issuers: ['super:cool:test:issuer'],
        agency_abbreviation: 'ABC',
        time_range: Date.new(2024, 12, 1)..Date.new(2024, 12, 7),
      )

      expect(report_maker.issuers).to eq(['super:cool:test:issuer'])
      expect(report_maker.agency_abbreviation).to eq('ABC')
      expect(report_maker.time_range).to eq(Date.new(2024, 12, 1)..Date.new(2024, 12, 7))
    end
  end
end
