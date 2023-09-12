require 'rails_helper'

RSpec.describe Reports::IdentityVerificationReport do
  before do
    allow(IdentityConfig.store).to receive(:s3_reports_enabled).and_return(true)
  end

  describe '#perform' do
    it 'gets a CSV from the report maker and saves it to S3' do
      report_maker = double(Reporting::IdentityVerificationReport, to_csv: 'I am a CSV, see')
      allow(subject).to receive(:report_maker).and_return(report_maker)
      expect(subject).to receive(:save_report).with(
        'identity-verification-report',
        'I am a CSV, see',
        extension: 'csv',
      )

      subject.perform(Date.new(2023, 12, 25))
    end
  end

  describe '#report_maker' do
    it 'is a identity verification report maker with the right time range' do
      report_date = Date.new(2023, 12, 25)

      subject.report_date = report_date

      expect(subject.report_maker.time_range).to eq(report_date.all_day)
    end
  end
end
