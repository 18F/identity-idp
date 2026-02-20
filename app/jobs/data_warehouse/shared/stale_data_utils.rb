# frozen_string_literal: true

require 'identity/hostdata'
require 'reporting/cloudwatch_client'

module DataWarehouse
  module Shared
    module StaleDataUtils
      REPORT_NAME = 'cw_log_duplicate_counts'
      NUM_THREADS = 6

      def cloudwatch_client(log_group_name: nil, slice_interval: 1.day)
        Reporting::CloudwatchClient.new(
          log_group_name: log_group_name,
          ensure_complete_logs: false,
          num_threads: NUM_THREADS,
          slice_interval: slice_interval,
        )
      end

      def duplicate_row_count_file_path(log_group_name, timestamp)
        lg_name = get_short_log_group_name(log_group_name)
        year = timestamp.year
        file_name = timestamp.strftime('%Y-%m-%d')
        "table_summary_stats/#{REPORT_NAME}/#{lg_name}/#{year}/#{file_name}.csv"
      end

      def get_short_log_group_name(log_group_name)
        log_group_name.split('/').last.tr('.', '_')
      end

      def log_groups
        [
          "#{env}_/srv/idp/shared/log/events.log",
          "#{env}_/srv/idp/shared/log/production.log",
        ]
      end

      def log_stream_filter_map
        base_log_group = "#{env}_/srv/idp/shared/log"
        {
          "#{base_log_group}/events.log" => "@logStream like 'worker-i-' or @logStream like 'idp-i-'", # rubocop:disable Layout/LineLength
          "#{base_log_group}/production.log" => "@logStream like 'idp-i-'",
        }
      end

      def cloudwatch_query(log_group_name)
        <<~QUERY
          fields jsonParse(@message) as @messageJson
          | filter #{log_stream_filter_map[log_group_name]}
          | filter isPresent(@messageJson)
          | stats count() as row_count
        QUERY
      end

      def log_group_offset_query(log_group_name)
        <<~QUERY
          fields jsonParse(@message) as @messageJson, concat(@timestamp, @message) as ts_plus_message
          | filter #{log_stream_filter_map[log_group_name]}
          | filter isPresent(@messageJson)
          | stats count() as cnt by ts_plus_message
          | stats sum(cnt - 1) as offset_count
        QUERY
      end

      def s3_file_exists?(s3_path)
        s3_client.head_object(bucket: bucket_name, key: s3_path)
        true
      rescue => e
        logger.warn(
          "#{class_name}: S3 head_object check failed for s3://#{bucket_name}/#{s3_path} with error: #{e.message}", # rubocop:disable Layout/LineLength
        )
        false
      end

      def read_duplicate_counts_from_s3(s3_path)
        unless s3_file_exists?(s3_path)
          return {}
        end
        logger.info("Reading existing duplicate counts from s3://#{bucket_name}/#{s3_path}")
        body_text = s3_client.get_object(bucket: bucket_name, key: s3_path).body.read
        body_text.split("\n").each_with_object({}) do |line, result|
          hour, count = line.split(',')
          result[hour.to_i] = count.to_i
        end
      end

      def upload_duplicate_counts_to_s3(s3_path, csv_data)
        logger.info("Uploading duplicate counts to s3://#{bucket_name}/#{s3_path}")
        upload_file_to_s3_bucket(
          path: s3_path,
          body: csv_data,
          content_type: 'text/csv',
          bucket: bucket_name,
        )
      end
    end
  end
end
