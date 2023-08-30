require 'rails_helper'
require 'csv'

RSpec.describe Reports::MonthlyAccountReuseReport do
  subject(:report) { Reports::MonthlyAccountReuseReport.new }

  let(:report_date) { Date.new(2021, 3, 1) }
  let(:s3_public_reports_enabled) { true }
  let(:s3_report_bucket_prefix) { 'reports-bucket' }
  let(:s3_report_public_bucket_prefix) { 'public-reports-bucket' }
  let(:s3_report_path) do
    'int/monthly-account-reuse-report/2021/2021-03-01.monthly-account-reuse-report.json'
  end

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
          path: s3_report_path,
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
            path: s3_report_path,
            bucket: 'reports-bucket.1234-us-west-1',
          ),
        ).exactly(1).time.and_call_original

        report.perform(report_date)
      end
    end

    context 'with data' do
      let(:timestamp) { report_date - 12.days }
      let(:timestamp2) { report_date + 12.days }

      let(:agency) { create(:agency, name: 'The Agency') }
      let(:agency2) { create(:agency, name: 'The Other Agency') }
      let(:agency3) { create(:agency, name: 'The Other Other Agency') }

      before do
        create(
          :service_provider,
          issuer: 'a',
          iaa: 'iaa123',
          friendly_name: 'The App',
          agency: agency,
        )
        create(
          :service_provider,
          issuer: 'b',
          iaa: 'iaa456',
          friendly_name: 'The Other App',
          agency: agency2,
        )
        create(
          :service_provider,
          issuer: 'c',
          iaa: 'iaa789',
          friendly_name: 'The Other Other App',
          agency: agency3,
        )

        # Seed the database with data to be queried - anything with `timestamp2` should be filtered
        ServiceProviderIdentity.create(
          user_id: 1, service_provider: 'a',
          last_ial2_authenticated_at: timestamp, verified_at: timestamp
        )
        ServiceProviderIdentity.create(
          user_id: 1, service_provider: 'b',
          last_ial2_authenticated_at: timestamp, verified_at: timestamp
        )
        ServiceProviderIdentity.create(
          user_id: 2, service_provider: 'a',
          last_ial2_authenticated_at: timestamp, verified_at: timestamp
        )
        ServiceProviderIdentity.create(
          user_id: 2, service_provider: 'b',
          last_ial2_authenticated_at: timestamp, verified_at: timestamp2
        )
        ServiceProviderIdentity.create(
          user_id: 3, service_provider: 'a',
          last_ial2_authenticated_at: timestamp, verified_at: timestamp
        )
        ServiceProviderIdentity.create(
          user_id: 3, service_provider: 'b',
          last_ial2_authenticated_at: timestamp, verified_at: timestamp
        )
        ServiceProviderIdentity.create(
          user_id: 3, service_provider: 'c',
          last_ial2_authenticated_at: timestamp, verified_at: timestamp2
        )
        ServiceProviderIdentity.create(
          user_id: 4, service_provider: 'a',
          last_ial2_authenticated_at: timestamp, verified_at: timestamp
        )
        ServiceProviderIdentity.create(
          user_id: 4, service_provider: 'b',
          last_ial2_authenticated_at: timestamp, verified_at: timestamp
        )
        ServiceProviderIdentity.create(
          user_id: 4, service_provider: 'c',
          last_ial2_authenticated_at: timestamp, verified_at: timestamp
        )
        ServiceProviderIdentity.create(
          user_id: 5, service_provider: 'a',
          last_ial2_authenticated_at: timestamp, verified_at: timestamp
        )
        ServiceProviderIdentity.create(
          user_id: 5, service_provider: 'b',
          last_ial2_authenticated_at: timestamp, verified_at: timestamp
        )
        ServiceProviderIdentity.create(
          user_id: 5, service_provider: 'c',
          last_ial2_authenticated_at: timestamp, verified_at: timestamp
        )
        ServiceProviderIdentity.create(
          user_id: 6, service_provider: 'a',
          last_ial2_authenticated_at: timestamp, verified_at: timestamp
        )
        ServiceProviderIdentity.create(
          user_id: 6, service_provider: 'b',
          last_ial2_authenticated_at: timestamp, verified_at: timestamp
        )

        (1..10).each do |_|
          create(:profile, :active, activated_at: timestamp)
        end
        (1..3).each do |_|
          create(:profile, :active, activated_at: timestamp2)
        end
      end

      it 'aggregates by issuer' do
        expect(report).to receive(:upload_file_to_s3_bucket).
          exactly(2).times do |path:, body:, content_type:, bucket:|
            parsed = JSON.parse(body, symbolize_names: true)

            expect(parsed[:report_date]).to eq(report_date.strftime('%Y-%m-01'))
            expect(parsed[:month]).to eq(report_date.prev_month(1).strftime('%b-%Y'))
            actual_csv = parsed[:results]
            expected_csv = [
              ['IDV app reuse rate Feb-2021'],
              ['Num. SPs', 'Num. users', 'Percentage'],
              [2, 3, 30.0],
              [3, 2, 20.0],
              ['Total (all >1)', 5, 50.0],
              [],
              ['Total proofed identities'],
              ['Total proofed identities (Feb-2021)', 10],
            ]
            expect(actual_csv.first).to eq(expected_csv)
          end

        report.perform(report_date)
      end
    end
  end
end
