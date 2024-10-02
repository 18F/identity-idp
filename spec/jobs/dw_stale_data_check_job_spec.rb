require 'rails_helper'
require 'aws-sdk-s3'
require 'csv'

RSpec.configure do |rspec|
  rspec.expect_with :rspec do |c|
    c.max_formatted_output_length = nil
  end
end

RSpec.describe DwStaleDataCheck do
  binding.pry
end
  # describe '#perform' do
  #   let(:timestamp) { Time.zone.now.yesterday.end_of_day }
  #   let(:job) { described_class.new }
  #   let(:s3_client) { Aws::S3::Client.new(stub_responses: true) }
  #   let(:bucket_name) { 'test-analytics-export-bucket' }
  #   let(:object_key) { 'test_max_id_object_key' }

  #   before do
  #     # Stub S3 client responses
  #     s3_client.stub_responses(:list_buckets, buckets: [{ name: bucket_name }])
  #     s3_client.stub_responses(:list_objects_v2, contents: [])
  #     s3_client.stub_responses(:get_object, body: StringIO.new("table_name, max_id, row_count\ntest_table,2,2"))

  #     # Clean the database
  #     ActiveRecord::Base.connection.execute('TRUNCATE TABLE test_table RESTART IDENTITY')
      
  #     # Insert test data
  #     ActiveRecord::Base.connection.execute("INSERT INTO test_table (id, created_at) VALUES (1, '#{timestamp - 1.day}'), (2, '#{timestamp - 2.days}')")
  #   end

  #   it 'fetches the max ids and row counts from Active Record and uploads to S3' do
  #     job.perform(timestamp)

  #     response = s3_client.get_object(bucket: bucket_name, key: object_key)
  #     csv_content = response.body.read
  #     csv = CSV.parse(csv_content, headers: true)

  #     expect(csv.headers).to include('table_name', 'max_id', 'row_count')
  #     expect(csv[0]['table_name']).to eq('test_table')
  #     expect(csv[0]['max_id']).to eq('2')
  #     expect(csv[0]['row_count']).to eq('2')
  #   end

  #   it 'retries fetching data from Active Record if an error occurs' do
  #     allow(ActiveRecord::Base.connection).to receive(:execute).and_raise(StandardError.new('test error')).twice.and_call_original

  #     job.perform(timestamp)

  #     response = s3_client.get_object(bucket: bucket_name, key: object_key)
  #     csv_content = response.body.read
  #     csv = CSV.parse(csv_content, headers: true)

  #     expect(csv.headers).to include('table_name', 'max_id', 'row_count')
  #     expect(csv[0]['table_name']).to eq('test_table')
  #     expect(csv[0]['max_id']).to eq('2')
  #     expect(csv[0]['row_count']).to eq('2')
  #   end

  #   it 'raises an error if fetching data fails after retries' do
  #     allow(ActiveRecord::Base.connection).to receive(:execute).and_raise(StandardError.new('test error')).exactly(3).times.and_call_original

  #     expect { job.perform(timestamp) }.to raise_error(RuntimeError, /Failed to fetch table max ids and counts after 2 attempts/)
  #   end
  # end
