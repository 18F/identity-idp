# frozen_string_literal: true

module Reports
  # This job reads pre-generated demographics CSV files from S3 and emails them to partners.
  # It's designed to run a few days after the end of a reporting period to account for
  # data processing delays.
  #
  # @param end_reporting_window_date [Time] The date that represents the end of the reporting
  #   period, e.g., Feb 28th for "month of February". This should be the date when the report
  #   would have been executed if there were no data sync lags. For contemporary reports,
  #   this should be a couple days before today's date.
  #
  # @param report_receiver [Symbol] :internal (Login only) or :both (partners + Login)
  # @param time_frame [String] 'quarterly' for now - determines time range for report
  #
  #   Note: Even though the demographics report is currently a "quarterly" time range, we are
  #         sending it monthly internally, and so end_reporting_window_date should be the end of the
  #         most recent month.
  # @example
  #   # Manual execution for February 2025 data (run on March 4th, time range Jan 1 - March 31)
  #   job = Reports::DemographicsMetricsS3Report.new(
  #     Date.parse('2026-02-28').end_of_day,
  #     :both,
  #     'monthly'
  #   )
  #   job.perform()
  class Reports::DemographicsMetricsS3Report < BaseReport
    include JobHelpers::ServiceProviderMetadata

    REPORT_NAME = 'demographics-metrics-s3-report'
    TIME_FRAME = 'quarterly' # Report coverage is full quarter even if run mid quarter internally
    MAX_FILE_AGE_DAYS = 30 # Realistically, report should have been generated within a few days
    REPORT_DELAY_DAYS = 5 # Cron job assumed to run 4th day of new month

    attr_reader :end_reporting_window_date, :report_receiver, :time_frame

    def initialize(init_end_date = nil, init_receiver = :internal, init_time_frame = TIME_FRAME,
                   *args, **rest)
      @end_reporting_window_date = init_end_date
      @report_receiver = init_receiver.to_sym
      @time_frame = init_time_frame
      super(init_end_date, init_receiver, init_time_frame, *args, **rest)
    end

    def perform(perform_end_date = nil, perform_receiver = :internal,
                perform_time_frame = TIME_FRAME)
      # Use perform params if provided, otherwise fall back to constructor values, then defaults
      @end_reporting_window_date = perform_end_date || @end_reporting_window_date ||
                                   REPORT_DELAY_DAYS.days.ago.end_of_day
      @report_receiver = (perform_receiver || @report_receiver || :internal).to_sym
      @time_frame = perform_time_frame || @time_frame || TIME_FRAME

      raise ArgumentError, 'end_reporting_window_date is required' unless @end_reporting_window_date

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

    def effective_end_date
      # Matches logic in reporting-rails, handles quarterly reports that are run
      # mid-quarter by setting end date to end of month, not end of quarter
      @effective_end_date ||= [@end_reporting_window_date.all_month.end, report_time_range.end].min
    end

    def effective_end_date_formatted
      effective_end_date.strftime('%Y%m%d')
    end

    def start_date_formatted
      report_time_range.begin.strftime('%Y%m%d')
    end

    def start_date_display
      report_time_range.begin.strftime('%Y-%m-%d')
    end

    def end_date_display
      effective_end_date.strftime('%Y-%m-%d')
    end

    def time_label
      "#{start_date_display} - #{end_date_display}"
    end

    def incomplete_quarterly
      # These should only be sent internally
      effective_end_date != report_time_range.end && @time_frame == 'quarterly'
    end

    def process_issuer_report(config)
      issuer_string = config['issuer_string']
      # Get service provider info using helper
      sp_info = get_service_provider_info(issuer_string)
      unless sp_info
        Rails.logger.error "No service provider found for issuer: #{issuer_string} - skipping"
        return
      end

      agency_abbreviation = sp_info['agency_abbreviation']
      sp_id = sp_info[:id]

      internal_emails = Array(config['internal_emails']).select(&:present?)
      partner_emails = Array(config['partner_emails']).select(&:present?)
      unless validate_config(config, issuer_string)
        return
      end
      email_addresses = determine_email_addresses(
        internal_emails, partner_emails,
        agency_abbreviation
      )
      return unless email_addresses
      Rails.logger.info "Processing demographics report for issuer: #{issuer_string}"

      report_reader = create_report_reader(sp_id, agency_abbreviation)

      unless validate_report_freshness(report_reader)
        Rails.logger.error "Report files are too old or missing for issuer: "\
                           "#{issuer_string} - skipping"
        return
      end

      send_demographics_email(
        email_addresses: email_addresses,
        report_reader: report_reader,
        agency_abbreviation: agency_abbreviation,
      )
      Rails.logger.info "Successfully sent demographics report for issuer: #{issuer_string}"
    rescue StandardError => e
      Rails.logger.error "Failed to process demographics report for issuer #{issuer_string}:"\
                         " #{e.message}"
      # Continue processing other issuers instead of failing the entire job
    end

    def create_report_reader(sp_id, agency_abbreviation)
      report_time_range
      # Example: DemographicsMetricsReport/001/quarterly/SP001_20260101-20260228_state_metrics.csv
      # See app/jobs/reports/demographics_metrics_report.rb for filepath logic
      base_path = generate_base_s3_path(directory: 'idp')
      s3_path = "#{base_path}DemographicsMetricsReport/#{sp_id}/"\
                "#{@time_frame}/SP#{sp_id}_#{start_date_formatted}_#{effective_end_date_formatted}"
      Reporting::DemographicsMetricsReportS3.new(
        bucket_name: data_warehouse_bucket_name,
        custom_s3_path: s3_path,
        agency_abbreviation: agency_abbreviation,
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

    def determine_email_addresses(internal_emails, partner_emails, agency_abbreviation)
      if @report_receiver == :both && partner_emails.empty?
        Rails.logger.warn(
          "#{agency_abbreviation} Demographics Metrics Report: recipient is :both " \
          "but no external email specified",
        )
      end
      if @report_receiver == :both && partner_emails.present?
        to_emails = partner_emails
        bcc_emails = internal_emails
      else
        to_emails = internal_emails
        bcc_emails = []
      end
      # Filter out empty emails
      to_emails = to_emails.select(&:present?)
      bcc_emails = bcc_emails.select(&:present?)
      if to_emails.empty? && bcc_emails.empty?
        Rails.logger.warn "No emails received - #{agency_abbreviation} "\
                          "Demographics Metrics Report NOT SENT"
        return nil
      end
      { to: to_emails, bcc: bcc_emails }
    end

    def send_demographics_email(email_addresses:, report_reader:, agency_abbreviation:)
      validate_email_logic(email_addresses)
      ReportMailer.tables_report(
        to: email_addresses[:to],
        bcc: email_addresses[:bcc],
        subject: demographics_email_subject(agency_abbreviation),
        reports: report_reader.as_emailable_reports,
        message: demographics_email_preamble,
        attachment_format: :csv,
      ).deliver_now
    end

    def validate_email_logic(email_addresses)
      if incomplete_quarterly
        Rails.logger.info "Sending incomplete quarterly data report - internal use only. "\
                          "File end date: #{effective_end_date_formatted}, "\
                          "Quarter end: #{report_time_range.end.strftime('%Y%m%d')}"
        # Check both to and bcc emails for external addresses
        all_emails = (email_addresses[:to] + email_addresses[:bcc])
        external_emails = all_emails.reject { |email| email.downcase.end_with?('gsa.gov') }
        if external_emails.any?
          Rails.logger.error "ERROR: Sending incomplete quarterly data to external emails: "\
                            "#{external_emails.join(', ')}. "\
                            "This should only go to internal GSA emails."
        end
      end
    end

    def demographics_email_subject(agency_abbreviation)
      if agency_abbreviation.blank?
        Rails.logger.warn 'Missing agency abbreviation'
        agency_abbreviation_formatted = ''
      else
        agency_abbreviation_formatted = "#{agency_abbreviation} "
      end
      "#{agency_abbreviation_formatted}Verification Demographics Report - #{time_label}"
    end

    def demographics_email_preamble
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
      ERB
    end

    def report_time_range
      case @time_frame
      when 'quarterly'
        @end_reporting_window_date.all_quarter
      when 'monthly'
        @end_reporting_window_date.all_month # Not expecting to run this yet
      else
        raise ArgumentError, "Unsupported time frame: #{@time_frame}"
      end
    end

    def report_configs
      configs = IdentityConfig.store.demographics_metrics_s3_report_configs || []
      # Set default report_receiver if not specified
      configs.map do |config|
        config['report_receiver'] ||= 'internal'
        config
      end
    end

    def validate_config(config, issuer_string)
      required_fields = %w[issuer_string]
      missing_fields = required_fields.select { |field| config[field].nil? }
      if missing_fields.any?
        Rails.logger.error "Missing required fields for issuer #{issuer_string}:"\
                           " #{missing_fields.join(', ')}"
        return false
      end
      # Validate report_receiver if present
      if config['report_receiver'] && !%w[internal both].include?(config['report_receiver'])
        Rails.logger.error "Invalid report_receiver for issuer #{issuer_string}:"\
                           " #{config['report_receiver']}"
        return false
      end
      true
    end

    def data_warehouse_bucket_name
      bucket_prefix = IdentityConfig.store.s3_data_warehouse_replica_bucket_prefix
      aws_account_id = Identity::Hostdata.aws_account_id
      aws_region = Identity::Hostdata.aws_region
      "#{bucket_prefix}-#{aws_account_id}-#{aws_region}"
    end
  end
end
