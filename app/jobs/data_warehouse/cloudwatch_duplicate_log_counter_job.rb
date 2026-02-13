# frozen_string_literal: true

require 'reporting/cloudwatch_client'

module DataWarehouse
  class CloudWatchDuplicateLogCounterJob < BaseJob
    include Shared::StaleDataUtils

    REPORT_NAME = 'cw_log_duplicate_counts'
    NUM_THREADS = 6
    LOG_GROUPS = [
      "#{env}_/srv/idp/shared/log/events.log",
      "#{env}_/srv/idp/shared/log/production.log",
    ].freeze

    def perform(timestamp)
      return if data_warehouse_disabled?

      LOG_GROUPS.each do |log_group_name|
        logger.info("Processing log group #{log_group_name}, checking for duplicates.")
        error_msgs = []
        begin
          update_hourly_counts_file(log_group_name, timestamp)
        rescue => e
          msg = "Failed to update hourly counts for #{log_group_name}: #{e.message}"
          error_msgs << msg
          logger.error(msg)
        end
      end
      unless error_msgs.empty?
        raise "Errors occurred in the #{class_name}: #{error_msgs.join('; ')}"
      end
    end

    private

    def update_hourly_counts_file(log_group_name, timestamp)
      timestamp_minus_hour = timestamp - 1.hour
      s3_path = duplicate_row_count_file_path(log_group_name, timestamp_minus_hour)
      hourly_counts = read_duplicate_counts_from_s3(s3_path)
      hours_needed = hours_to_process(timestamp_minus_hour, hourly_counts)
      return if hours_needed.empty?

      hours_needed.each do |hour|
        logger.info("Checking for duplicates at hour #{hour}.")
        hourly_counts[hour] =
          count_hourly_duplicate_logs(log_group_name, timestamp_minus_hour, hour)
      end

      csv_data = hourly_counts.sort_by do |hour, _|
        hour
      end.map { |hour, count| "#{hour},#{count}" }.join("\n")
      upload_duplicate_counts_to_s3(csv_data, s3_path)
      logger.info("Successfully updated duplicate counts for hour bucket(s): #{hours_needed}.")
    end

    def hours_to_process(timestamp, hourly_counts)
      # Determine which hours need to be processed based on existing S3 data
      all_hours = (0..23).to_a
      current_hour = timestamp.hour
      all_hours.select do |hour|
        !hourly_counts.key?(hour) && hour <= current_hour
      end
    end

    def time_slices(timestamp, hour, num_slices)
      start_time = timestamp.beginning_of_day + hour.hours
      1.hour
      1.second

      slice_duration = 1.hour / num_slices

      slices = []
      num_slices.times do |i|
        slice_start = start_time + (i * slice_duration)
        slice_end = slice_start + slice_duration - 1.second
        slices << (slice_start..slice_end)
      end
      slices
    end

    def count_hourly_duplicate_logs(log_group_name, timestamp, hour)
      results = cloudwatch_client(log_group_name: log_group_name, num_threads: NUM_THREADS).fetch(
        query: log_group_offset_query(log_group_name),
        time_slices: time_slices(timestamp, hour, NUM_THREADS),
      )
      results.sum { |h| h['offset_count'].to_i }
    end

    # def read_duplicate_counts_from_s3(s3_bucket_name, s3_path)
    #   logger.info("Reading existing duplicate counts from s3://#{s3_bucket_name}/#{s3_path}")
    #   body_text = s3_client.get_object(bucket: s3_bucket_name, key: s3_path).body.read
    #   body_text.split("\n").each_with_object({}) do |line, result|
    #     hour, count = line.split(',')
    #     result[hour.to_i] = count.to_i
    #   end
    # end

    # def upload_duplicate_counts_to_s3(s3_bucket_name, s3_path, csv_data)
    #   logger.info("Uploading duplicate counts to s3://#{s3_bucket_name}/#{s3_path}")
    #   upload_file_to_s3_bucket(
    #     path: s3_path,
    #     body: csv_data,
    #     content_type: 'text/csv',
    #     bucket: s3_bucket_name,
    #   )
    # end
  end
end
