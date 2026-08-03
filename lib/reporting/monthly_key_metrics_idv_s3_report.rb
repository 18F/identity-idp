# frozen_string_literal: true

require 'csv'

module Reporting
  # Reads the pre-generated IDV key-metrics CSV reports (condensed IDV + proofing rate)
  # that reporting-rails generates from Redshift and uploads to S3, and presents them
  # as emailable reports so the Monthly Key Metrics email matches what the in-app
  # CloudWatch-based reports used to produce (99.9% similar in prod testing 6/26 and 5/26)
  class MonthlyKeyMetricsIdvS3Report
    attr_reader :bucket_name, :s3_path

    CONDENSED_IDV_FILENAME = 'condensed_idv'
    PROOFING_RATE_FILENAME = 'proofing_rate_metrics'

    CSV_FILE_NAMES = [
      CONDENSED_IDV_FILENAME,
      PROOFING_RATE_FILENAME,
    ].freeze

    # @param [String] bucket_name the S3 bucket name
    # @param [String] custom_s3_path S3 key prefix for the reports
    def initialize(bucket_name:, custom_s3_path:)
      @bucket_name = bucket_name
      @s3_path = custom_s3_path
    end

    def as_emailable_reports
      [
        condensed_idv_emailable_report,
        proofing_rate_emailable_report,
      ]
    end

    # Mirrors Reporting::MonthlyIdvReport#monthly_idv_report_emailable_report
    def condensed_idv_emailable_report
      Reporting::EmailableReport.new(
        title: 'Proofing Rate Metrics',
        subtitle: 'Condensed (NEW)', # (NEW) was in original formatting
        float_as_percent: true,
        precision: 2,
        table: condensed_idv_table,
        filename: CONDENSED_IDV_FILENAME,
      )
    end

    # Mirrors Reporting::ProofingRateReport#proofing_rate_emailable_report
    def proofing_rate_emailable_report
      Reporting::EmailableReport.new(
        subtitle: 'Detail',
        float_as_percent: true,
        precision: 2,
        table: proofing_rate_table,
        filename: PROOFING_RATE_FILENAME,
      )
    end

    def condensed_idv_table
      csv_data_for(CONDENSED_IDV_FILENAME)
    end

    def proofing_rate_table
      csv_data_for(PROOFING_RATE_FILENAME)
    end

    def csv_file_names
      CSV_FILE_NAMES
    end

    # @param [String] report_name one of CSV_FILE_NAMES
    def csv_data_for(report_name)
      @csv_cache ||= {}
      @csv_cache[report_name] ||= begin
        body = fetch_csv_from_s3(report_name)
        CSV.parse(body).map { |row| row.map { |cell| coerce_cell(cell) } }
      end
    end

    # Get the last modified time for a specific file
    # @return [Time] last modified time
    # @raise [Aws::S3::Errors::NoSuchKey] if the file doesn't exist
    def get_file_last_modified(report_name)
      key = "#{s3_path}_#{report_name}.csv"
      resp = s3_helper.s3_client.head_object(bucket: bucket_name, key: key)
      resp.last_modified
    end

    private

    # CSV stores everything as strings. The original EmailableReport received real
    # Integers and Floats. Recreate that so:
    #   - integer-looking cells (counts) -> Integer
    #   - decimal-looking cells (rates) -> Float (so float_as_percent kicks in)
    #   - everything else (labels, dates) -> left as the original String
    def coerce_cell(cell)
      return cell unless cell.is_a?(String)

      stripped = cell.strip
      return cell if stripped.empty?

      if stripped.match?(/\A-?\d+\z/)
        Integer(stripped)
      elsif stripped.match?(/\A-?\d*\.\d+\z/)
        Float(stripped)
      else
        cell
      end
    rescue ArgumentError
      cell
    end

    # Builds the full S3 object key for the given CSV report name and fetches it.
    # Key format: "<s3_path>_<report_name>.csv"
    # @return [String] raw CSV body
    def fetch_csv_from_s3(report_name)
      key = "#{s3_path}_#{report_name}.csv"
      resp = s3_helper.s3_client.get_object(bucket: bucket_name, key: key)
      resp.body.read

      # Shouldn't fail, already verified file exists in job
    rescue Aws::S3::Errors::NoSuchKey => e
      Rails.logger.error "Unexpected failure reading CSV file from S3: #{key} - #{e}"
      raise
    end

    def s3_helper
      @s3_helper ||= JobHelpers::S3Helper.new
    end
  end
end
