# frozen_string_literal: true

require 'csv'
begin
  require 'reporting/command_line_options'
rescue LoadError => e
  warn 'could not load paths, try running with "bundle exec rails runner"'
  raise e
end

module Reporting
  class FraudMetricsLg99ReportS3
    attr_reader :time_range

    CSV_FILE_NAMES = %w[
      lg99_metrics
      suspended_metrics
      reinstated_metrics
    ].freeze

    # @param [Range<Time>] time_range
    # @param [String] bucket_name the S3 bucket name
    # @param [String] s3_path_prefix the S3 key prefix \
    # (e.g. "fraud-metrics-report/2026/2026-03-04.fraud-metrics-report")
    # @param [Aws::S3::Client, nil] s3_client optional injectable S3 client
    def initialize(
      time_range:,
      bucket_name:,
      s3_path_prefix:,
      s3_client: nil
    )
      @time_range = time_range
      @bucket_name = bucket_name
      @s3_path_prefix = s3_path_prefix
      @s3_client = s3_client
    end

    def as_emailable_reports
      [
        Reporting::EmailableReport.new(
          title: "Monthly LG-99 Metrics #{stats_month}",
          table: lg99_metrics_table,
          filename: 'lg99_metrics',
        ),
        Reporting::EmailableReport.new(
          title: "Monthly Suspended User Metrics #{stats_month}",
          table: suspended_metrics_table,
          filename: 'suspended_metrics',
        ),
        Reporting::EmailableReport.new(
          title: "Monthly Reinstated User Metrics #{stats_month}",
          table: reinstated_metrics_table,
          filename: 'reinstated_metrics',
        ),
      ]
    end

    def lg99_metrics_table
      csv_data_for('lg99_metrics')
    end

    def suspended_metrics_table
      csv_data_for('suspended_metrics')
    end

    def reinstated_metrics_table
      csv_data_for('reinstated_metrics')
    end

    def stats_month
      time_range.begin.strftime('%b-%Y')
    end

    # Returns parsed CSV data (array of arrays) for the given report name.
    # Memoized per report name.
    # @param [String] report_name one of CSV_FILE_NAMES
    # @return [Array<Array<String>>]
    def csv_data_for(report_name)
      @csv_cache ||= {}
      @csv_cache[report_name] ||= begin
        body = fetch_csv_from_s3(report_name)
        CSV.parse(body)
      end
    end

    private

    # Builds the full S3 object key for the given CSV report name and fetches it.
    # Key format: "<s3_path_prefix>/<report_name>.csv"
    # @param [String] report_name
    # @return [String] raw CSV body
    def fetch_csv_from_s3(report_name)
      key = "#{@s3_path_prefix}/#{report_name}.csv"
      resp = s3_client.get_object(bucket: @bucket_name, key: key)
      resp.body.read
    end

    def s3_client
      require 'aws-sdk-s3'

      @s3_client ||= Aws::S3::Client.new(
        http_open_timeout: 5,
        http_read_timeout: 5,
        compute_checksums: false,
      )
    end
  end
end
