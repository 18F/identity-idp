# frozen_string_literal: true

require 'csv'

module Reporting
  # Reads pre-generated demographics CSV reports from S3 and presents them as emailable reports.
  class DemographicsMetricsReportS3
    attr_reader :bucket_name, :s3_path, :agency_abbreviation

    CSV_FILE_NAMES = %w[
      definitions
      overview
      age_metrics
      state_metrics
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
          title: "#{agency_abbreviation_prefix}Age Metrics",
          table: age_metrics_table,
          filename: 'age_metrics',
        ),
        Reporting::EmailableReport.new(
          title: "#{agency_abbreviation_prefix}State Metrics",
          table: state_metrics_table,
          filename: 'state_metrics',
        ),
      ]
    end

    def definitions_table
      csv_data_for('definitions')
    end

    def overview_table
      csv_data_for('overview')
    end

    def age_metrics_table
      csv_data_for('age_metrics')
    end

    def state_metrics_table
      csv_data_for('state_metrics')
    end

    def csv_file_names
      CSV_FILE_NAMES
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

    # Get the last modified time for a specific file
    # @param [String] report_name
    # @return [Time] last modified time
    # @raise [Aws::S3::Errors::NoSuchKey] if the file doesn't exist
    def get_file_last_modified(report_name)
      key = "#{s3_path}_#{report_name}.csv"
      resp = s3_helper.s3_client.head_object(bucket: bucket_name, key: key)
      resp.last_modified
    end

    private

    def agency_abbreviation_prefix
      if agency_abbreviation.present?
        "#{agency_abbreviation} "
      else
        ''
      end
    end

    # Builds the full S3 object key for the given CSV report name and fetches it.
    # Key format: "<s3_path>_<report_name>.csv"
    # @param [String] report_name
    # @return [String] raw CSV body
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
