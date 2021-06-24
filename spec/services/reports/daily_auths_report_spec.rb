require 'rails_helper'

RSpec.describe Reports::DailyAuthsReport do
  subject(:report) { Reports::DailyAuthsReport.new(report_date) }

  let(:report_date) { Date.new(2021, 3, 1) }

  before do
    allow(Identity::Hostdata).to receive(:env).and_return('int')
  end

  describe '#call' do
    it 'uploads a file to S3 based on the report date' do
      expect(report).to receive(:upload_file_to_s3_bucket).with(
        path: 'int/daily-auths-report/2021/2021-03-01.daily-auths-report.json',
        body: kind_of(String),
        content_type: 'application/json',
      )

      report.call
    end

    context 'with data' do
      let(:timestamp) { report_date + 12.hours }

      before do
        create(:service_provider, issuer: 'a', iaa: 'iaa123')
        create(:sp_return_log, ial: 1, issuer: 'a', requested_at: timestamp, returned_at: timestamp)
        create(:sp_return_log, ial: 1, issuer: 'a', requested_at: timestamp, returned_at: timestamp)
        create(:sp_return_log, ial: 2, issuer: 'a', requested_at: timestamp, returned_at: timestamp)
      end

      it 'aggregates by issuer' do
        expect(report).to receive(:upload_file_to_s3_bucket) do |path:, body:, content_type:|
          parsed = JSON.parse(body, symbolize_names: true)

          expect(parsed[:start]).to eq(report_date.beginning_of_day.as_json)
          expect(parsed[:finish]).to eq(report_date.end_of_day.as_json)
          expect(parsed[:results]).to match_array(
            [
              { count: 2, ial: 1, issuer: 'a', iaa: 'iaa123' },
              { count: 1, ial: 2, issuer: 'a', iaa: 'iaa123' },
            ],
          )
        end

        report.call
      end
    end
  end
end
