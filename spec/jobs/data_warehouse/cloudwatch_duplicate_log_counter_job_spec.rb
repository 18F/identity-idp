require 'rails_helper'

RSpec.describe DataWarehouse::CloudwatchDuplicateLogCounterJob, type: :job do
  let(:timestamp) { Date.new(2025, 10, 10).in_time_zone('UTC').end_of_day }
  let(:job) { described_class.new }
  let(:expected_bucket) { 'login-gov-analytics-export-test-1234-us-west-2' }
  let(:s3_data_warehouse_bucket_prefix) { 'login-gov-analytics-export' }
  let(:data_warehouse_enabled) { true }

  before do
    allow(Identity::Hostdata).to receive(:env).and_return('test')
    allow(Identity::Hostdata).to receive(:aws_account_id).and_return('1234')
    allow(Identity::Hostdata).to receive(:aws_region).and_return('us-west-2')
    allow(IdentityConfig.store).to receive(:s3_data_warehouse_bucket_prefix).and_return(s3_data_warehouse_bucket_prefix) # rubocop:disable Layout/LineLength
    allow(IdentityConfig.store).to receive(:data_warehouse_enabled).and_return(data_warehouse_enabled) # rubocop:disable Layout/LineLength

    stub_cloudwatch_logs(
      [{ 'offset_count' => '6' }],
    )
    Aws.config[:s3] = {
      stub_responses: {
        put_object: {},
      },
    }
  end

  describe '#perform' do
    context 'when data warehouse is disabled' do
      let(:data_warehouse_enabled) { false }

      it 'raises an error' do
        expect(job).not_to receive(:update_hourly_counts_file)
        expect do
          job.perform(timestamp)
        end.to raise_error('Data warehouse is disabled, cannot run the job.')
      end
    end

    context 'when data warehouse is enabled' do
      let(:data_warehouse_enabled) { true }

      it 'processes each log group and updates counts' do
        allow(job).to receive(:update_hourly_counts_file)

        job.perform(timestamp)

        expect(job).to have_received(:update_hourly_counts_file).with(
          "#{Identity::Hostdata.env}_/srv/idp/shared/log/events.log", timestamp
        )
        expect(job).to have_received(:update_hourly_counts_file).with(
          "#{Identity::Hostdata.env}_/srv/idp/shared/log/production.log", timestamp
        )
      end

      it 'handles exceptions and logs errors' do
        allow(job).to receive(:update_hourly_counts_file).and_raise(StandardError.new('Test error'))
        expect(Rails.logger).to receive(:error).with(/Failed to update hourly counts for/).twice
        expect do
          job.perform(timestamp)
        end.to raise_error(/Errors occurred in the DataWarehouse::CloudwatchDuplicateLogCounterJob run/) # rubocop:disable Layout/LineLength
      end
    end
  end

  describe '#hours_to_process' do
    it 'returns hours that are missing in hourly_counts and are <= current hour' do
      timestamp = Time.zone.parse('2025-10-10 15:00:00')
      hourly_counts = { 0 => 1, 1 => 2, 2 => 3 }
      expected_hours = (0..15).to_a - hourly_counts.keys
      result = job.send(:hours_to_process, timestamp, hourly_counts)
      expect(result).to eq(expected_hours)
    end

    it 'returns an empty array if all hours are present' do
      timestamp = Time.zone.parse('2025-10-10 15:00:00')
      hourly_counts = (0..15).each_with_object({}) { |hour, hash| hash[hour] = hour }
      result = job.send(:hours_to_process, timestamp, hourly_counts)
      expect(result).to eq([])
    end

    it 'returns only the prior hour' do
      timestamp = Time.zone.parse('2025-10-10 15:00:00')
      hourly_counts = (0..14).each_with_object({}) { |hour, hash| hash[hour] = hour }
      result = job.send(:hours_to_process, timestamp, hourly_counts)
      expect(result).to eq([15])
    end
  end

  describe '#time_slices' do
    it 'returns correct time slices for a given hour' do
      timestamp = Time.zone.parse('2025-10-10 00:00:00')
      hour = 1
      num_slices = 6
      (1 - 0.999999999).seconds
      expected_slices = [
        Time.zone.local(
          2025, 10, 10, 1, 0,
          0
        )..(Time.zone.local(2025, 10, 10, 1, 10, 0) - 1.second).end_of_minute,
        Time.zone.local(
          2025, 10, 10, 1, 10,
          0
        )..(Time.zone.local(2025, 10, 10, 1, 20, 0) - 1.second).end_of_minute,
        Time.zone.local(
          2025, 10, 10, 1, 20,
          0
        )..(Time.zone.local(2025, 10, 10, 1, 30, 0) - 1.second).end_of_minute,
        Time.zone.local(
          2025, 10, 10, 1, 30,
          0
        )..(Time.zone.local(2025, 10, 10, 1, 40, 0) - 1.second).end_of_minute,
        Time.zone.local(
          2025, 10, 10, 1, 40,
          0
        )..(Time.zone.local(2025, 10, 10, 1, 50, 0) - 1.second).end_of_minute,
        Time.zone.local(
          2025, 10, 10, 1, 50,
          0
        )..(Time.zone.local(2025, 10, 10, 2, 0, 0) - 1.second).end_of_minute,
      ]
      result = job.send(:time_slices, timestamp, hour, num_slices)
      expect(result).to eq(expected_slices)
    end
  end

  describe '#count_hourly_duplicate_logs' do
    it 'returns the total count of duplicate logs for the given hour' do
      log_group_name = "#{Identity::Hostdata.env}_/srv/idp/shared/log/events.log"
      timestamp = Time.zone.parse('2025-10-10 00:00:00')
      hour = 1

      result = job.send(:count_hourly_duplicate_logs, log_group_name, timestamp, hour)
      expect(result).to eq(36)
    end
  end

  describe '#update_hourly_counts_file' do
    it 'reads existing counts and uploads updated counts to S3' do
      log_group_name = "#{Identity::Hostdata.env}_/srv/idp/shared/log/events.log"
      timestamp = Time.zone.parse('2025-10-10 03:00:00')
      allow(job).to receive(:read_duplicate_counts_from_s3).and_return({ 0 => 1, 1 => 2 })
      allow(job).to receive(:upload_duplicate_counts_to_s3)

      job.send(:update_hourly_counts_file, log_group_name, timestamp)

      s3_path = job.duplicate_row_count_file_path(log_group_name, timestamp - 1.hour)
      expect(job).to have_received(:read_duplicate_counts_from_s3).with(s3_path)
      expect(job).to have_received(:upload_duplicate_counts_to_s3).with(s3_path, "0,1\n1,2\n2,36")
    end
  end
end
