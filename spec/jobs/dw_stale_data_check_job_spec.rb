require 'rails_helper'

RSpec.describe DwStaleDataCheckJob, type: :job do
  let(:timestamp) { Time.zone.now.end_of_day }
  let(:job) { described_class.new }
  let(:expected_bucket) { 'login-gov-analytics-export-test-1234-us-west-2' }
  let(:expected_object_key) { "idp_max_ids/#{timestamp.strftime('%Y-%m-%d')}_idp_max_ids.json" }
  let(:test_on_tables) { ['users'] }
  let(:s3_bucket) { instance_double('Aws::S3::Bucket', name: expected_bucket) }
  let(:s3_object) { instance_double('Aws::S3::Object') }
  let(:s3_resource) { instance_double('Aws::S3::Resource', bucket: s3_bucket) }

  let(:expected_json) do
    {
      'users' => {
        'max_id' => 2,
        'row_count' => 2,
      }
    }.to_json
  end

  before do
    allow(Identity::Hostdata).to receive_messages(
      env: 'test',
      aws_account_id: '1234',
      aws_region: 'us-west-2',
    )

    allow(Aws::S3::Resource).to receive(:new).and_return(s3_resource)
    allow(s3_bucket).to receive(:object).with(expected_object_key).and_return(s3_object)
    allow(s3_object).to receive(:put).and_return(true)
  end

  describe '#perform' do
    context 'when actual database tables contain data' do
      it 'generates correct JSON from database tables' do
        allow(ActiveRecord::Base.connection).to receive(:tables).and_return(test_on_tables)
        add_data_to_tables

        json_data = upload_json_to_s3

        expect(json_data).to eq(expected_json)
      end
    end

    context 'when tables are empty' do
      let(:expected_json) { { 'users' => { 'max_id' => nil, 'row_count' => 0 } }.to_json }

      it 'handles empty tables gracefully' do
        allow(ActiveRecord::Base.connection).to receive(:tables).and_return(test_on_tables)

        json_data = upload_json_to_s3

        expect { job.perform(timestamp) }.not_to raise_error
        expect(json_data).to eq(expected_json)
      end
    end

    context 'when tables are missing the id column' do
      let(:expected_json) { {}.to_json }

      it 'skips tables without id column' do
        allow(ActiveRecord::Base.connection).to receive(:tables).and_return(['non_id_table'])
        allow(ActiveRecord::Base.connection).to receive(:columns).with('non_id_table').
          and_return([double(name: 'name')])

        json_data = upload_json_to_s3

        expect { job.perform(timestamp) }.not_to raise_error
        expect(json_data).to eq(expected_json)
      end
    end

    context 'when uploading to S3' do
      it 'uploads data to S3 successfully' do
        allow(ActiveRecord::Base.connection).to receive(:tables).and_return(test_on_tables)
        add_data_to_tables

        job.perform(timestamp)

        expect(s3_object).to have_received(:put).with(body: expected_json).once
        expect(Aws::S3::Resource).to have_received(:new).once
        expect(s3_bucket.name).to eq(expected_bucket)
        expect(s3_bucket).to have_received(:object).with(expected_object_key).once
      end

      it 'raises an error if the S3 upload fails' do
        allow(s3_object).to receive(:put).and_raise(
          Aws::S3::Errors::ServiceError.new(nil, 'Failed to upload'),
        )

        expect do
          job.perform(timestamp)
        end.to raise_error(Aws::S3::Errors::ServiceError, 'Failed to upload')
      end
    end
  end

  private

  def add_data_to_tables
    User.create!(id: 1, created_at: 1.day.ago)
    User.create!(id: 2, created_at: 1.hour.ago)
  end

  def upload_json_to_s3
    json_data = nil
    allow(s3_object).to receive(:put) do |args|
      json_data = args[:body]
      true
    end
    job.perform(timestamp)
    json_data
  end
end
