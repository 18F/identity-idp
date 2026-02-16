# frozen_string_literal: true

module DataWarehouse
  class CloudwatchDuplicateLogCounterJob < BaseJob
    include Shared::StaleDataUtils

    def perform(timestamp)
      unless !data_warehouse_disabled?
        raise 'Data warehouse is disabled, cannot run the job.'
      end

      error_msgs = []
      log_groups.each do |log_group_name|
        logger.info("Processing log group #{log_group_name}, checking for duplicates.")
        begin
          update_hourly_counts_file(log_group_name, timestamp)
        rescue => e
          msg = "Failed to update hourly counts for #{log_group_name}: #{e.message}"
          error_msgs << msg
          logger.error(msg)
        end
      end
      unless error_msgs.empty?
        raise "Errors occurred in the #{class_name} run: #{error_msgs.join('; ')}"
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
      upload_duplicate_counts_to_s3(s3_path, csv_data)
      logger.info("Successfully updated duplicate counts for hour bucket(s): #{hours_needed}.")
    end

    def hours_to_process(timestamp, hourly_counts)
      all_hours = (0..23).to_a
      current_hour = timestamp.hour
      all_hours.select do |hour|
        !hourly_counts.key?(hour) && hour <= current_hour
      end
    end

    def time_slices(timestamp, hour, num_slices)
      start_time = timestamp.beginning_of_day + hour.hours
      slice_duration = 1.hour / num_slices

      slices = []
      num_slices.times do |i|
        slice_start = start_time + (i * slice_duration)
        slice_end = (slice_start + slice_duration - 1.second).end_of_minute
        slices << (slice_start..slice_end)
      end
      slices
    end

    def count_hourly_duplicate_logs(log_group_name, timestamp, hour)
      results = cloudwatch_client(log_group_name: log_group_name).fetch(
        query: log_group_offset_query(log_group_name),
        time_slices: time_slices(timestamp, hour, NUM_THREADS),
      )
      results.sum { |h| h['offset_count'].to_i }
    end
  end
end
