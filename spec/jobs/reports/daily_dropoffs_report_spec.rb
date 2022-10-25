require 'rails_helper'

RSpec.describe Reports::DailyDropoffsReport do
  subject(:report) { Reports::DailyDropoffsReport.new }

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
          path: 'int/daily-dropoffs-report/2021/2021-03-01.daily-dropoffs-report.csv',
          body: kind_of(String),
          content_type: 'text/csv',
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
            path: 'int/daily-dropoffs-report/2021/2021-03-01.daily-dropoffs-report.csv',
            bucket: 'reports-bucket.1234-us-west-1',
          ),
        ).exactly(1).time.and_call_original

        report.perform(report_date)
      end
    end

    context 'with data' do
      let(:timestamp) { report_date + 12.hours }

      let(:agency) { create(:agency, name: 'The Agency') }
      let(:service_provider) do
        create(
          :service_provider,
          issuer: 'issuer1',
          iaa: 'iaa123',
          friendly_name: 'The App',
          agency: agency,
        )
      end

      before do
        started_user = create(:user)
        last_step_user = create(:user)
        verified_user = create(:user)

        create(
          :doc_auth_log,
          user: started_user,
          service_provider: service_provider,
          welcome_view_at: timestamp,
        )

        # going through all the funnel steps
        [last_step_user, verified_user].each do |user|
          create(
            :doc_auth_log,
            user: user,
            service_provider: service_provider,
            agreement_view_at: timestamp,
            welcome_view_at: timestamp,
            document_capture_view_at: timestamp,
            document_capture_submit_count: 1,
            ssn_view_at: timestamp,
            verify_view_at: timestamp,
            verify_submit_count: 1,
            verify_phone_view_at: timestamp,
            encrypt_view_at: timestamp,
            verified_view_at: timestamp,
          )
        end

        create(:profile, user: verified_user, verified_at: timestamp, active: true)
      end

      it 'aggregates by issuer' do
        expect(report).to receive(:upload_file_to_s3_bucket).
          exactly(2).times do |path:, body:, content_type:, bucket:|
            csv = CSV.parse(body, headers: true)

            row = csv.first

            expect(row['issuer']).to eq(service_provider.issuer)
            expect(row['friendly_name']).to eq(service_provider.friendly_name)
            expect(row['iaa']).to eq(service_provider.iaa)
            expect(row['agency']).to eq(agency.name)
            expect(row['start']).to eq(report_date.beginning_of_day.iso8601)
            expect(row['finish']).to eq(report_date.end_of_day.iso8601)

            # all 3 users started
            expect(row['welcome'].to_i).to eq(3)

            # 2 users went through the full funnel
            expect(row['agreement'].to_i).to eq(2)
            expect(row['capture_document'].to_i).to eq(2)
            expect(row['cap_doc_submit'].to_i).to eq(2)
            expect(row['ssn'].to_i).to eq(2)
            expect(row['verify_info'].to_i).to eq(2)
            expect(row['verify_submit'].to_i).to eq(2)
            expect(row['phone'].to_i).to eq(2)
            expect(row['encrypt'].to_i).to eq(2)
            expect(row['personal_key'].to_i).to eq(2)

            # only 1 user verified
            expect(row['verified'].to_i).to eq(1)
          end

        report.perform(report_date)
      end
    end
  end
end
