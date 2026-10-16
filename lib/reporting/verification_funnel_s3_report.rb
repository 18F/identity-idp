# frozen_string_literal: true

require 'csv'

module Reporting
  # Reads pre-generated verification funnel CSV reports from S3 and presents them
  # as emailable reports
  class VerificationFunnelS3Report
    attr_reader :bucket_name, :s3_path, :agency_abbreviation

    CSV_FILE_NAMES = %w[
      definitions
      overview
      verification_funnel_metrics
    ].freeze

    # @param [String] bucket_name the S3 bucket name
    # @param [String] custom_s3_path S3 key prefix for the reports
    # @param [String, nil] agency_abbreviation - agency abbreviation for table prefixes
    def initialize(bucket_name:, custom_s3_path:, agency_abbreviation: nil)
      @bucket_name = bucket_name
      @s3_path = custom_s3_path
      @agency_abbreviation = agency_abbreviation
    end

    def as_emailable_reports
      [
        Reporting::EmailableReport.new(
          title: 'Definitions',
          table: definitions_table,
          filename: 'definitions',
        ),
        Reporting::EmailableReport.new(
          title: 'Overview',
          table: overview_table,
          filename: 'overview',
        ),
        Reporting::EmailableReport.new(
          title: "#{agency_abbreviation_prefix}Verification Funnel Metrics",
          float_as_percent: true,
          precision: 2,
          table: verification_funnel_metrics_table,
          filename: 'verification_funnel_metrics',
        ),
      ]
    end

    def definitions_table
      csv_data_for('definitions')
    end

    def overview_table
      csv_data_for('overview')
    end

    def verification_funnel_metrics_table
      csv_data_for('verification_funnel_metrics')
    end

    def csv_file_names
      CSV_FILE_NAMES
    end

    # Returns parsed CSV data (array of arrays) for the given report name.
    # @return [Array<Array<String>>]
    def csv_data_for(report_name)
      @csv_cache ||= {}
      @csv_cache[report_name] ||= begin
        body = fetch_csv_from_s3(report_name)
        CSV.parse(body).map { |row| row.map { |cell| coerce_cell(cell) } }
      end
    end

    # @return [Time] last modified time
    # @raise [Aws::S3::Errors::NotFound] if the file doesn't exist (head_object)
    def get_file_last_modified(report_name)
      key = "#{s3_path}_#{report_name}.csv"
      resp = s3_helper.s3_client.head_object(bucket: bucket_name, key: key)
      resp.last_modified
    end

    private

    # CSV stores everything as strings. The producer writes Integers (counts) and
    # Floats (rates); recreate that here so:
    #   - integer-looking cells (counts) -> Integer
    #   - decimal-looking cells (rates) -> Float (so float_as_percent kicks in
    #     in the mailer template)
    #   - everything else (labels, headers) -> left as the original String
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

    def agency_abbreviation_prefix
      if agency_abbreviation.present?
        "#{agency_abbreviation} "
      else
        ''
      end
    end

    # Builds the full S3 object key for the given CSV report name and fetches it.
    # @raise [Aws::S3::Errors::NoSuchKey] if the CSV file does not exist in S3
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
