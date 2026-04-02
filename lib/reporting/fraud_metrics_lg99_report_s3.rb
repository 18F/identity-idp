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
    # @param [String] bucket_name the S3 bucket name (without env prefix,
    #   e.g. "login-gov-dw-reports-894947205914-us-west-2")
    # @param [String, nil] env the deployment environment (e.g. "sliang", "prod");
    #   prepended to the S3 key as "<env>/idp/..." when deriving from report_date
    # @param [Date, nil] report_date when provided, the S3 key prefix is derived automatically
    #   as "<env>/idp/fraud-metrics-report/<YEAR>/<YYYY-MM-DD>.fraud-metrics-report"
    # @param [String, nil] custom_s3_path explicit S3 key prefix; overrides report_date derivation
    #   (e.g. "sliang/idp/fraud-metrics-report/2026/2026-03-04.fraud-metrics-report")
    # @raise [ArgumentError] if neither report_date nor custom_s3_path is provided
    def initialize(
      time_range:,
      bucket_name:,
      env: nil,
      report_date: nil,
      custom_s3_path: nil
    )
      if custom_s3_path.nil? && report_date.nil?
        raise ArgumentError, 'Must provide either report_date or custom_s3_path'
      end

      @time_range = time_range
      @bucket_name = bucket_name
      @custom_s3_path = custom_s3_path ||
                        "#{env}/idp/fraud-metrics-report/#{report_date.year}/" \
                        "#{report_date.strftime('%F')}.fraud-metrics-report"
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
    # Key format: "<custom_s3_path>/<report_name>.csv"
    # @param [String] report_name
    # @return [String] raw CSV body
    # @raise [Aws::S3::Errors::NoSuchKey] if the CSV file does not exist in S3
    def fetch_csv_from_s3(report_name)
      key = "#{@custom_s3_path}/#{report_name}.csv"
      Rails.logger.info(
        "#{self.class.name}#fetch_csv_from_s3: fetching s3://#{@bucket_name}/#{key}",
      )
      resp = s3_helper.s3_client.get_object(bucket: @bucket_name, key: key)
      resp.body.read
    rescue Aws::S3::Errors::NoSuchKey => e
      Rails.logger.error(
        "#{self.class.name}#fetch_csv_from_s3: CSV file not found in S3 " \
        "(bucket=#{@bucket_name}, key=#{key}): #{e.message}",
      )
      raise
    rescue Aws::S3::Errors::ServiceError => e
      Rails.logger.error(
        "#{self.class.name}#fetch_csv_from_s3: S3 service error while fetching " \
        "(bucket=#{@bucket_name}, key=#{key}): #{e.message}",
      )
      raise
    end

    def s3_helper
      @s3_helper ||= JobHelpers::S3Helper.new
    end
  end
end
