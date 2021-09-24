require 'rails_helper'

RSpec.describe Reports::DailyAuthsReport do
  subject(:report) { Reports::DailyAuthsReport.new }

  let(:report_date) { Date.new(2021, 3, 1) }
  let(:s3_public_reports_enabled) { true }
  let(:s3_report_bucket_prefix) { 'reports-bucket' }
  let(:s3_report_public_bucket_prefix) { 'public-reports-bucket' }

  before do
    allow(Identity::Hostdata).to receive(:env).and_return('int')
    allow(Identity::Hostdata).to receive(:aws_account_id).and_return('1234')
    allow(Identity::Hostdata).to receive(:aws_region).and_return('us-west-1')
    allow(IdentityConfig.store).to receive(:s3_public_reports_enabled).
      and_return(s3_public_reports_enabled)
    allow(IdentityConfig.store).to receive(:s3_report_bucket_prefix).
      and_return(s3_report_bucket_prefix)
    allow(IdentityConfig.store).to receive(:s3_report_public_bucket_prefix).
      and_return(s3_report_public_bucket_prefix)

    Aws.config[:s3] = {
      stub_responses: {
        put_object: {},
      },
    }
  end

  describe '#perform' do
    it 'uploads a file to S3 based on the report date' do
      ['reports-bucket.1234-us-west-1', 'public-reports-bucket-int.1234-us-west-1'].each do |bucket|
        expect(report).to receive(:upload_file_to_s3_bucket).with(
          path: 'int/daily-auths-report/2021/2021-03-01.daily-auths-report.json',
          body: kind_of(String),
          content_type: 'application/json',
          bucket: bucket,
        ).exactly(1).time.and_call_original
      end

      expect(report).to receive(:report_body).and_call_original.once

      report.perform(report_date)
    end

    context 'when s3 public reports are disabled' do
      let(:s3_public_reports_enabled) { false }

      it 'only uploads to one bucket' do
        expect(report).to receive(:upload_file_to_s3_bucket).with(
          hash_including(
            path: 'int/daily-auths-report/2021/2021-03-01.daily-auths-report.json',
            bucket: 'reports-bucket.1234-us-west-1',
          ),
        ).exactly(1).time.and_call_original

        report.perform(report_date)
      end
    end

    context 'with data' do
      let(:timestamp) { report_date + 12.hours }

      let(:agency) { create(:agency, name: 'The Agency') }

      before do
        create(
          :service_provider,
          issuer: 'a',
          iaa: 'iaa123',
          friendly_name: 'The App',
          agency: agency,
        )
        create(:sp_return_log, ial: 1, issuer: 'a', requested_at: timestamp, returned_at: timestamp)
        create(:sp_return_log, ial: 1, issuer: 'a', requested_at: timestamp, returned_at: timestamp)
        create(:sp_return_log, ial: 2, issuer: 'a', requested_at: timestamp, returned_at: timestamp)
      end

      it 'aggregates by issuer' do
        expect(report).to receive(:upload_file_to_s3_bucket).
          exactly(2).times do |path:, body:, content_type:, bucket:|
            parsed = JSON.parse(body, symbolize_names: true)

            expect(parsed[:start]).to eq(report_date.beginning_of_day.as_json)
            expect(parsed[:finish]).to eq(report_date.end_of_day.as_json)
            expect(parsed[:results]).to match_array(
              [
                {
                  count: 2,
                  ial: 1,
                  issuer: 'a',
                  iaa: 'iaa123',
                  friendly_name: 'The App',
                  agency: 'The Agency',
                },
                {
                  count: 1,
                  ial: 2,
                  issuer: 'a',
                  iaa: 'iaa123',
                  friendly_name: 'The App',
                  agency: 'The Agency',
                },
              ],
            )
          end

        report.perform(report_date)
      end
    end
  end

  describe '#good_job_concurrency_key' do
    let(:date) { Time.zone.today }

    it 'is the job name and the date' do
      job = described_class.new(date)
      expect(job.good_job_concurrency_key).
        to eq("#{described_class::REPORT_NAME}-#{date}")
    end
  end
end
