# frozen_string_literal: true

require 'csv'

module Reporting
  # Reads pre-generated CSV reports from S3 and presents them as emailable reports.
  # This is currently manually-run dark code. In the future, this may be converted
  # to a job inheriting from BaseReport.
  class FraudMetricsLg99ReportS3
    attr_reader :time_range

    CSV_FILE_NAMES = %w[
      lg99_metrics
      suspended_metrics
      reinstated_metrics
    ].freeze

    # @param [Range<Time>] time_range
    # @param [String] bucket_name the S3 bucket name
    # @param [Date, nil] report_date when provided, the S3 path prefix is derived automatically
    #   as "fraud-metrics-report/<YEAR>/<YYYY-MM-DD>.fraud-metrics-report"
    # @param [String, nil] s3_path_prefix explicit S3 key prefix; overrides report_date derivation
    #   (e.g. "fraud-metrics-report/2026/2026-03-04.fraud-metrics-report")
    # @raise [ArgumentError] if neither report_date nor s3_path_prefix is provided
    def initialize(
      time_range:,
      bucket_name:,
      report_date: nil,
      s3_path_prefix: nil
    )
      if s3_path_prefix.nil? && report_date.nil?
        raise ArgumentError, 'Must provide either report_date or s3_path_prefix'
      end

      @time_range = time_range
      @bucket_name = bucket_name
      @s3_path_prefix = s3_path_prefix ||
                        "fraud-metrics-report/#{report_date.year}/ \
                        #{report_date.strftime('%F')}.fraud-metrics-report"
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
      $stdout.puts "[FraudMetricsLg99ReportS3] Fetching S3 object: \
       bucket=#{@bucket_name} key=#{key}"
      resp = s3_helper.s3_client.get_object(bucket: @bucket_name, key: key)
      $stdout.puts "[FraudMetricsLg99ReportS3] Response: \
      content_length=#{resp.content_length} content_type=#{resp.content_type}"
      resp.body.read
    end

    def s3_helper
      @s3_helper ||= JobHelpers::S3Helper.new
    end
  end
end
