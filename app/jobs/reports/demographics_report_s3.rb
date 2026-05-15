# frozen_string_literal: true

require 'csv'

module Reports
  # This job reads pre-generated demographics CSV files from S3 and emails them to partners.
  #
  # @param run_date [Time] When the job runs (defaults to now)
  # @param days_back [Integer] How many days to look back for the reporting period (defaults to 5)
  # @param receiver [Symbol] :internal (Login only) or :both (partners + Login)
  # @param time_frame [String] 'quarterly' for now - determines time range for report
  #
  # @example
  #   # Manual execution (run on March 5th for Q1 data, looking back 5 days)
  #   job = Reports::DemographicsMetricsS3Report.new(
  #     Time.zone.now,  # run_date
  #     5,              # days_back_for_time_period
  #     :both,          # receiver
  #     'quarterly'     # time_frame
  #   )
  #   job.perform
  class Reports::DemographicsMetricsS3Report < BaseReport
    include JobHelpers::ServiceProviderMetadata

    REPORT_NAME = 'demographics-metrics-s3-report'
    TIME_FRAME = 'quarterly' # Report coverage is full quarter even if run mid quarter internally
    MAX_FILE_AGE_DAYS = 30 # Realistically, report should have been generated within a few days
    REPORT_DELAY_DAYS = 5 # Cron job assumed to run 4th day of new month

    attr_reader :run_date, :days_back_for_time_period, :report_receiver, :time_frame

    # rubocop:disable Metrics/ParameterLists
    def initialize(init_run_date = Time.zone.now, init_days_back_for_time_period = 5,
                   init_receiver = :internal, init_time_frame = TIME_FRAME,
                   *args, **rest)
      # rubocop:enable Metrics/ParameterLists
      @run_date = init_run_date
      @days_back_for_time_period = init_days_back_for_time_period
      @report_receiver = init_receiver.to_sym
      @time_frame = init_time_frame
      super(init_run_date, init_days_back_for_time_period, init_receiver, *args, **rest)
    end

    # rubocop:disable Metrics/ParameterLists
    def perform(perform_run_date = nil, perform_days_back_for_time_period = nil,
                perform_receiver = nil, perform_time_frame = nil)
      # rubocop:enable Metrics/ParameterLists
      # Use perform params if provided, otherwise fall back to constructor values, then defaults
      @run_date = perform_run_date || @run_date || Time.zone.now
      @days_back_for_time_period = perform_days_back_for_time_period ||
                                   @days_back_for_time_period ||
                                   5
      @report_receiver = (perform_receiver || @report_receiver || :internal).to_sym
      @time_frame = perform_time_frame || @time_frame || TIME_FRAME

      unless @days_back_for_time_period.between?(0, 90)
        raise ArgumentError, "days_back_for_time_period must be between 0 and 90, "\
                            "got #{@days_back_for_time_period}. Adjust run_date for periods "\
                            "greater than 90 days."
      end

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
      # Get service provider info using helper
      sp_info = get_service_provider_info(issuer_string)
      unless sp_info
        Rails.logger.error "No service provider found for issuer: #{issuer_string} - skipping"
        return
      end

      agency_abbreviation = sp_info[:agency_abbreviation] 
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
      # Determine file suffix based on report_receiver
      file_prefix = (@report_receiver == :internal) ? 'latest' : 'latest_external'

      base_path = generate_base_S3_path(directory: 'idp')
      s3_path = "#{base_path}DemographicsMetricsReport/#{sp_id}/"\
                "#{@time_frame}/#{report_time_range_label}/#{file_prefix}_SP#{sp_id}"

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
      ReportMailer.tables_report(
        to: email_addresses[:to],
        bcc: email_addresses[:bcc],
        subject: demographics_email_subject(agency_abbreviation, report_reader),
        reports: report_reader.as_emailable_reports,
        message: demographics_email_preamble,
        attachment_format: :csv,
      ).deliver_now
    end

    def demographics_email_subject(agency_abbreviation, report_reader)
      if agency_abbreviation.blank?
        Rails.logger.warn 'Missing agency abbreviation'
        agency_abbreviation_formatted = ''
      else
        agency_abbreviation_formatted = "#{agency_abbreviation} "
      end

      # Get file date from S3, fallback to today
      report_date = get_report_file_date(report_reader)

      "#{agency_abbreviation_formatted}Demographics Report "\
      "#{report_time_range_label} - #{report_date}"
    end

    def get_report_file_date(report_reader)
      # Try to get the last modified date from the first available file
      report_reader.csv_file_names.each do |file_name|
        begin
          last_modified = report_reader.get_file_last_modified(file_name)
          return last_modified.strftime('%Y-%m-%d')
        rescue Aws::S3::Errors::NoSuchKey
          next
        end
      end
      # Fallback to today if no files found
      Date.current.strftime('%Y-%m-%d')
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
        @run_date.prev_day(@days_back_for_time_period).all_quarter
      when 'monthly'
        @run_date.prev_day(@days_back_for_time_period).all_month
      when 'daily'
        @run_date.prev_day(@days_back_for_time_period).all_day
      else
        raise ArgumentError, "Unsupported time frame: #{@time_frame}"
      end
    end

    def report_time_range_label
      end_of_range = report_time_range.end
      case @time_frame
      when 'quarterly'
        q_int = ((end_of_range.month - 1) / 3) + 1
        label_start = "Q#{q_int}" # Q1
      when 'monthly'
        label_start = end_of_range.strftime('%b') # Jan
      when 'daily'
        label_start = "#{end_of_range.strftime('%b')}"\
                      "#{end_of_range.strftime('%d')}" # Jan01
      else
        raise ArgumentError, "Unsupported time frame: #{@time_frame}"
      end
      "#{label_start}#{end_of_range.strftime('%Y')}" # Q12026, Jan2026, Jan012026
    end

    def report_configs
      configs = IdentityConfig.store.demographics_metrics_S3_report_configs || []
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
