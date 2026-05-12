# frozen_string_literal: true

require 'csv'
require 'reporting/demographics_metrics_report_s3'

module Reports
  class DemographicsMetricsS3Report < BaseReport
    include JobHelpers::ServiceProviderMetadata

    REPORT_NAME = 'demographics-metrics-s3-report'
    TIME_FRAME = 'quarterly' # Could eventually be monthly, etc.
    MAX_FILE_AGE_DAYS = 30
    REPORT_DELAY_DAYS = 4 # Account for data processing lags, 1 day later than reporting-rails delay

    attr_reader :report_date, :time_frame

    def initialize(report_date = nil, time_frame = TIME_FRAME, *args, **rest)
      @report_date = report_date
      @time_frame = time_frame
      super(report_date, time_frame, *args, **rest)
    end

    def perform(date = Time.zone.yesterday.end_of_day, time_frame = TIME_FRAME)
      @report_date = date || @report_date || REPORT_DELAY_DAYS.days.ago.end_of_day
      @time_frame = time_frame

      issuer_configs = report_configs
      if issuer_configs.empty?
        Rails.logger.warn 'No issuer configurations found - Demographics Metrics S3 Report NOT SENT'
        return false
      end

      Rails.logger.info "Processing demographics reports for #{issuer_configs.length} issuers"

      issuer_configs.each do |config|
        process_issuer_report(config)
      end

      Rails.logger.info 'Completed demographics metrics S3 report processing'
    end

    private

    def process_issuer_report(config)
      issuer_string = config['issuer_string']
      email_addresses = Array(config['emails']).select(&:present?)

      if email_addresses.empty?
        Rails.logger.warn "No email addresses found for issuer #{issuer_string} - skipping"
        return
      end

      Rails.logger.info "Processing demographics report for issuer: #{issuer_string}"

      # Get service provider info using helper
      sp_info = get_service_provider_info(issuer_string)
      unless sp_info
        Rails.logger.error "No service provider found for issuer: #{issuer_string} - skipping"
        return
      end

      # Create report reader
      report_reader = create_report_reader(sp_info)

      # Validate file freshness
      unless validate_report_freshness(report_reader)
        Rails.logger.error "Report files are too old or missing for issuer: "\
                           "#{issuer_string} - skipping"
        return
      end

      # Send email
      send_demographics_email(
        email_addresses: email_addresses,
        sp_info: sp_info,
        report_reader: report_reader,
      )

      Rails.logger.info "Successfully sent demographics report for issuer: #{issuer_string}"
    rescue StandardError => e
      Rails.logger.error "Failed to process demographics report for issuer #{issuer_string}: #{e.message}"
      # Continue processing other issuers instead of failing the entire job
    end

    def create_report_reader(sp_info)
      time_range_obj = report_time_range
      start_date = time_range_obj.begin.strftime('%Y%m%d')
      end_date = time_range_obj.end.strftime('%Y%m%d')
      sp_id = sp_info[:id]
      sp_agency_abbreviation = sp_info[:agency_abbreviation]

      # Matches file path from reporting-rails DemographicsMetricsReport
      s3_path = "DemographicsMetricsReport/#{sp_id}/"\
                "#{time_frame}/#{sp_id}_#{start_date}_#{end_date}"

      Reporting::DemographicsMetricsReportS3.new(
        report_time_range: time_range_obj,
        bucket_name: data_warehouse_bucket_name,
        custom_s3_path: s3_path,
        time_frame: time_frame,
        agency_abbreviation: sp_agency_abbreviation,
      )
    end

    def validate_report_freshness(report_reader)
      # Check if at least one of the expected files exists and is recent
      cutoff_time = MAX_FILE_AGE_DAYS.days.ago

      report_reader.csv_file_names.any? do |file_name|
        begin
          last_modified = report_reader.get_file_last_modified(file_name)
          last_modified > cutoff_time
        rescue Aws::S3::Errors::NoSuchKey
          false
        end
      end
    end

    def send_demographics_email(email_addresses:, sp_info:, report_reader:)
      ReportMailer.tables_report(
        to: email_addresses,
        subject: demographics_email_subject(sp_info),
        reports: report_reader.as_emailable_reports,
        message: demographics_email_preamble(sp_info),
        attachment_format: :xlsx,
      ).deliver_now
    end

    def demographics_email_subject(sp_info)
      agency_abbrev = sp_info[:agency_abbreviation]
      time_label = format_time_label(report_time_range.begin)

      # Log warning if missing critical metadata
      if agency_abbrev.blank?
        Rails.logger.warn "Missing agency abbreviation for service provider ID #{sp_info[:id]}"
      end

      # Build subject with graceful fallbacks
      subject_parts = []
      subject_parts << agency_abbrev if agency_abbrev.present?
      subject_parts << 'Demographics Metrics Report'
      subject_parts << time_label

      subject_parts.join(' ')
    end

    def demographics_email_preamble(sp_info)
      service_name = sp_info[:friendly_name] || 'your service'
      agency_name = sp_info[:agency_name] || 'your organization'
      time_label = format_time_label(report_time_range.begin)

      ERB.new(<<~ERB).result(binding).html_safe # rubocop:disable Rails/OutputSafety
        <% env = Identity::Hostdata.env || 'local' %>
        <% if env != 'prod' %>
          <div class="usa-alert usa-alert--info usa-alert--email">
            <div class="usa-alert__body">
              <h2 class="usa-alert__heading">Non-Production Report</h2>
              <p class="usa-alert__text">
                This was generated in the <strong><%= env %></strong> environment.
              </p>
            </div>
          </div>
        <% end %>
        
        <p>This report contains demographic ID verification metrics for <strong><%= service_name %></strong> 
        (<%= agency_name %>) for <%= time_label %>.</p>
      ERB
    end

    def format_time_label(date)
      case time_frame
      when 'quarterly'
        quarter = ((date.month - 1) / 3) + 1
        "Q#{quarter} #{date.year}"
      when 'monthly'
        date.strftime('%B %Y') # e.g., "May 2026"
      else
        # Fallback for any other time frames
        start_date = report_time_range.begin.strftime('%Y-%m-%d')
        end_date = report_time_range.end.strftime('%Y-%m-%d')
        "#{start_date} - #{end_date}"
      end
    end

    def report_time_range
      case time_frame
      when 'quarterly'
        report_date.all_quarter
      when 'monthly'
        report_date.all_month
      else
        raise ArgumentError, "Unsupported time frame: #{time_frame}"
      end
    end

    def report_configs
      IdentityConfig.store.demographics_metrics_email_configs || []
    end

    def data_warehouse_bucket_name
      bucket_prefix = IdentityConfig.store.s3_data_warehouse_replica_bucket_prefix
      aws_account_id = Identity::Hostdata.aws_account_id
      aws_region = Identity::Hostdata.aws_region
      "#{bucket_prefix}-#{aws_account_id}-#{aws_region}"
    end
  end
end
