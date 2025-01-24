require 'rails_helper'

RSpec.describe DataWarehouse::DailySensitiveColumnJob do
  subject(:job) { DataWarehouse::DailySensitiveColumnJob.new }

  let(:timestamp) { Date.new(2024, 10, 15).in_time_zone('UTC') }
  let(:job) { described_class.new }
  let(:expected_bucket) { "#{IdentityConfig.store.s3_idp_dw_tasks}-test-1234-us-west-2" }
  let(:tables) { ['auth_app_configurations'] }
  let(:s3_idp_dw_tasks) { 'login-gov-idp-dw-tasks' }

  let(:expected_json) do
    {
      sensitive: [
        {
          "object-locator": {
            "column-name": 'encrypted_otp_secret_key',
            "table-name": 'auth_app_configurations',
          },
        },
      ],
      insensitive: [
        {
          "object-locator": {
            "column-name": 'user_id',
            "table-name": 'auth_app_configurations',
          },
        },
        {
          "object-locator": {
            "column-name": 'name',
            "table-name": 'auth_app_configurations',
          },
        },
        {
          "object-locator": {
            "column-name": 'totp_timestamp',
            "table-name": 'auth_app_configurations',
          },
        },
        {
          "object-locator": {
            "column-name": 'created_at',
            "table-name": 'auth_app_configurations',
          },
        },
        {
          "object-locator": {
            "column-name": 'updated_at',
            "table-name": 'auth_app_configurations',
          },
        },
      ],
    }.to_json
  end

  let(:s3_metadata) do
    {
      body: anything,
      content_type: 'application/json',
      bucket: 'login-gov-idp-dw-tasks-int-1234-us-west-1',
    }
  end

  before do
    allow(Identity::Hostdata).to receive(:env).and_return('int')
    allow(Identity::Hostdata).to receive(:aws_account_id).and_return('1234')
    allow(Identity::Hostdata).to receive(:aws_region).and_return('us-west-1')
    allow(IdentityConfig.store).to receive(:s3_idp_dw_tasks)
      .and_return(s3_idp_dw_tasks)

    Aws.config[:s3] = {
      stub_responses: {
        put_object: {},
      },
    }
  end

  describe '#perform' do
    before do
      allow(ActiveRecord::Base.connection).to receive(:tables).and_return(tables)
    end

    context 'when bucket name is blank' do
      before do
        allow(IdentityConfig.store).to(
          receive(:s3_idp_dw_tasks),
        ).and_return('')
      end

      it 'skips trying to upload to S3' do
        expect(job).to_not receive(:upload_file_to_s3_bucket)
        job.perform(timestamp)
      end
    end

    context 'when bucket name is present' do
      it 'uploads a file to S3 based on the report date' do
        expect(job).to receive(:upload_file_to_s3_bucket).with(
          path: 'daily-sensitive-column-job/2024/2024-10-15_daily-sensitive-column-job.json',
          **s3_metadata,
        ).exactly(1).time.and_call_original
        job.perform(timestamp)
      end

      it 'data with the correct JSON structure' do
        data = job.fetch_columns
        expect(data).to eq(expected_json)
      end
    end
  end
end
