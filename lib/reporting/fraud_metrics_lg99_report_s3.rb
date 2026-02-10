# frozen_string_literal: true

require 'csv'
require 'aws-sdk-s3'

module Reporting
  class FraudMetricsLg99ReportFromS3
    attr_reader :s3_bucket, :s3_prefix, :s3_client

    FILENAMES = {
      lg99: 'lg99_metrics.csv',
      suspended: 'suspended_metrics.csv',
      reinstated: 'reinstated_metrics.csv',
    }.freeze

    Report = Struct.new(
      :lg99_unique_users_count,
      :unique_suspended_users_count,
      :average_days_creation_to_suspension,
      :average_days_proofed_to_suspension,
      :unique_reinstated_users_count,
      :average_days_to_reinstatement,
      :time_range,
      keyword_init: true,
    ) do
      def stats_month
        time_range.begin.strftime('%b-%Y')
      end
    end

    # @param s3_bucket [String] the name of the S3 bucket
    # @param s3_prefix [String] optional prefix/path within the bucket (e.g. "reports/2025-11/")
    # @param s3_client [Aws::S3::Client] an optional pre-configured S3 client (useful for testing)
    def initialize(s3_bucket:, s3_prefix: '', s3_client: nil)
      @s3_bucket = s3_bucket
      @s3_prefix = s3_prefix
      @s3_client = s3_client || Aws::S3::Client.new
    end

    # Reads all three CSV files from S3 and returns a populated Report struct.
    # @return [Report]
    def populate_report
      lg99_rows = parse_csv(fetch_csv(:lg99))
      suspended_rows = parse_csv(fetch_csv(:suspended))
      reinstated_rows = parse_csv(fetch_csv(:reinstated))

      time_range = extract_time_range(lg99_rows)

      Report.new(
        lg99_unique_users_count: extract_metric_value(
          lg99_rows, 'Unique users seeing LG-99'
        ),
        unique_suspended_users_count: extract_metric_value(
          suspended_rows, 'Unique users suspended'
        ),
        average_days_creation_to_suspension: extract_metric_value(
          suspended_rows, 'Average Days Creation to Suspension'
        ),
        average_days_proofed_to_suspension: extract_metric_value(
          suspended_rows, 'Average Days Proofed to Suspension'
        ),
        unique_reinstated_users_count: extract_metric_value(
          reinstated_rows, 'Unique users reinstated'
        ),
        average_days_to_reinstatement: extract_metric_value(
          reinstated_rows, 'Average Days to Reinstatement'
        ),
        time_range: time_range,
      )
    end

    private

    # Fetches a CSV file from S3 by its type key.
    # @param file_key [Symbol] one of :lg99, :suspended, :reinstated
    # @return [String] the raw CSV content
    def fetch_csv(file_key)
      filename = FILENAMES.fetch(file_key)
      s3_key = s3_prefix.empty? ? filename : "#{s3_prefix}#{filename}"

      response = s3_client.get_object(bucket: s3_bucket, key: s3_key)
      response.body.read
    end

    # Parses raw CSV content into an array of hashes.
    # @param csv_content [String]
    # @return [Array<Hash>]
    def parse_csv(csv_content)
      CSV.parse(csv_content, headers: true).map(&:to_h)
    end

    # Extracts the "Total" value for a given metric name from parsed CSV rows.
    # Returns an Integer for numeric values, or the raw string for non-numeric values (e.g. "n/a").
    # @param rows [Array<Hash>]
    # @param metric_name [String]
    # @return [Integer, Float, String]
    def extract_metric_value(rows, metric_name)
      row = rows.find { |r| r['Metric'] == metric_name }
      raise "Metric '#{metric_name}' not found in CSV data" unless row

      raw_value = row['Total']
      coerce_value(raw_value)
    end

    # Coerces a string value to an appropriate Ruby type.
    # @param value [String]
    # @return [Integer, Float, String]
    def coerce_value(value)
      return value if value == 'n/a'
      return value.to_i if value.match?(/\A\d+\z/)
      return value.to_f if value.match?(/\A\d+\.\d+\z/)

      value
    end

    # Extracts the time range from the first data row of any parsed CSV.
    # @param rows [Array<Hash>]
    # @return [Range<Time>]
    def extract_time_range(rows)
      row = rows.first
      raise 'No data rows found to extract time range' unless row

      range_start = Time.zone.parse(row['Range Start'])
      range_end = Time.zone.parse(row['Range End'])
      range_start..range_end
    end
  end
end
