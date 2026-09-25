# frozen_string_literal: true

require 'csv'
require 'reporting/verification_funnel_s3_report'

module Reports
  # This job reads pre-generated verification funnel CSV files from S3 and emails
  # them to partners. The CSVs are produced by Reports::VerificationFunnelReport in the
  # identity-reporting-rails app
  #
  # @param run_date [Time] When the job runs (defaults to now)
  # @param days_back [Integer] How many days to look back for the reporting period
  # @param receiver [Symbol] :internal (Login only) or :both (partners + Login)
  # @param time_frame [String] 'weekly' or 'monthly' - determines the report period
  #
  # @example
  #   job = Reports::VerificationFunnelS3Report.new(
  #     Time.zone.now,  # run_date
  #     1,              # days_back_for_time_period
  #     :both,          # receiver
  #     'weekly'        # time_frame
  #   )
  #   job.perform
  class VerificationFunnelS3Report < BaseReport
    include JobHelpers::ServiceProviderMetadata

    REPORT_NAME = 'VerificationFunnelReport' # Must match the producer's S3 folder
    DEFAULT_TIME_FRAME = 'weekly'
    MAX_FILE_AGE_DAYS = 30 # Realistically, report should have been generated within a few days
    DEFAULT_LOOK_BACK_DAYS = 1 # Producer uses a 1-day look-back; logs have negligible lag

    VALID_TIME_FRAMES = %w[daily weekly monthly quarterly].freeze

    attr_reader :run_date, :days_back_for_time_period, :report_receiver, :time_frame

    # rubocop:disable Metrics/ParameterLists
    def initialize(init_run_date = Time.zone.now,
                   init_days_back_for_time_period = DEFAULT_LOOK_BACK_DAYS,
                   init_receiver = :internal, init_time_frame = DEFAULT_TIME_FRAME,
                   *args, **rest)
      # rubocop:enable Metrics/ParameterLists
      @run_date = init_run_date
      @days_back_for_time_period = init_days_back_for_time_period
      @report_receiver = init_receiver.to_sym
      @time_frame = init_time_frame

      validate_parameters!

      super(init_run_date, init_days_back_for_time_period, init_receiver, *args, **rest)
    end

    # rubocop:disable Metrics/ParameterLists
    def perform(perform_run_date = nil, perform_days_back_for_time_period = nil,
                perform_receiver = nil, perform_time_frame = nil)
      # rubocop:enable Metrics/ParameterLists
      @run_date = perform_run_date || @run_date || Time.zone.now
      @days_back_for_time_period = perform_days_back_for_time_period ||
                                   @days_back_for_time_period ||
                                   DEFAULT_LOOK_BACK_DAYS
      @report_receiver = (perform_receiver || @report_receiver || :internal).to_sym
      @time_frame = perform_time_frame || @time_frame || DEFAULT_TIME_FRAME

      validate_parameters!

      # If 1st of month is monday, job is double scheduled. skip internal weekly run
      if @time_frame == 'monthly' && @report_receiver == :internal && @run_date.day == 1
        Rails.logger.info 'Skipping monthly verification funnel refresh - '\
                          '1st-of-month run covers today'
        return false
      end

      issuer_configs = report_configs
      if issuer_configs.empty?
        Rails.logger.warn 'No issuer configurations found - Verification Funnel S3 Report NOT SENT'
        return false
      end
      Rails.logger.info "Processing verification funnel reports for "\
                        "#{issuer_configs.length} issuers"
      issuer_configs.each do |config|
        process_issuer_report(config)
      end
      Rails.logger.info 'Completed verification funnel S3 report processing'
    end

    private

    def process_issuer_report(config)
      unless validate_config(config)
        return
      end

      issuer_string = config['issuer_string']
      # Get service provider info using helper (SQL call to app DB)
      sp_info = get_service_provider_info(issuer_string)
      unless sp_info
        Rails.logger.error "No service provider metadata found for issuer: "\
                           "#{issuer_string} - skipping"
        return
      end

      agency_abbreviation = sp_info[:agency_abbreviation]
      sp_id = sp_info[:id]

      internal_emails = Array(config['internal_emails']).select(&:present?)
      partner_emails = Array(config['partner_emails']).select(&:present?)

      email_addresses = determine_email_addresses(
        internal_emails, partner_emails,
        agency_abbreviation
      )
      return unless email_addresses
      Rails.logger.info "Processing verification funnel report for issuer: #{issuer_string}"

      report_reader = create_report_reader(sp_id, agency_abbreviation)

      # First check: Do all required files exist?
      unless validate_all_files_exist(report_reader, sp_info)
        return
      end

      # Second check: Are the files recent enough?
      unless validate_report_freshness(report_reader)
        Rails.logger.error "Report files are too old for issuer: #{issuer_string} - skipping"
        return
      end

      send_verification_funnel_email(
        email_addresses: email_addresses,
        report_reader: report_reader,
        agency_abbreviation: agency_abbreviation,
      )
      Rails.logger.info "Successfully sent verification funnel report for issuer: #{issuer_string}"
    rescue StandardError => e
      Rails.logger.error "Failed to process verification funnel report for issuer "\
                         "#{issuer_string}: #{e.message}"
      # Continue processing other issuers instead of failing the entire job
    end

    def create_report_reader(sp_id, agency_abbreviation)
      # Determine file suffix based on report_receiver
      file_prefix = (@report_receiver == :internal) ? 'latest' : 'latest_external'

      base_path = generate_base_s3_path(directory: 'idp')
      s3_path = "#{base_path}#{REPORT_NAME}/#{sp_id}/"\
                "#{@time_frame}/#{report_time_range_label}/#{file_prefix}_SP#{sp_id}"

      Reporting::VerificationFunnelS3Report.new(
        bucket_name: data_warehouse_bucket_name,
        custom_s3_path: s3_path,
        agency_abbreviation: agency_abbreviation,
      )
    end

    def validate_all_files_exist(report_reader, sp_info)
      missing_files = []
      report_reader.csv_file_names.each do |file_name|
        begin
          report_reader.get_file_last_modified(file_name)
        rescue Aws::S3::Errors::NoSuchKey
          missing_files << file_name
        end
      end
      if missing_files.any?
        Rails.logger.error "Missing report files for issuer: #{sp_info[:issuer_string]}"
        Rails.logger.error "  Service Provider ID: #{sp_info[:id]}"
        Rails.logger.error "  Agency: #{sp_info[:agency_abbreviation]}"
        Rails.logger.error "  Missing files: #{missing_files.join(', ')}"
        Rails.logger.error "  Expected path: #{report_reader.s3_path}_*.csv"
        Rails.logger.error "  Bucket: #{report_reader.bucket_name}"
        Rails.logger.error "  Time frame: #{@time_frame} (#{report_time_range_label})"
        Rails.logger.error "  Report receiver: #{@report_receiver}"
        return false
      end
      true
    end

    def validate_report_freshness(report_reader)
      # Check freshness of files we validated existence of
      cutoff_time = MAX_FILE_AGE_DAYS.days.ago

      report_reader.csv_file_names.all? do |file_name|
        begin
          last_modified = report_reader.get_file_last_modified(file_name)
          last_modified > cutoff_time
        rescue Aws::S3::Errors::NoSuchKey
          # Shouldn't happen if validate_all_files_exist passed, but just in case
          Rails.logger.error "Unexpected file access issue during freshness check despite"\
          " validate_all_files_exist passing for file: #{file_name}"
          false
        end
      end
    end

    def determine_email_addresses(internal_emails, partner_emails, agency_abbreviation)
      if @report_receiver == :both && partner_emails.empty?
        Rails.logger.warn(
          "#{agency_abbreviation} Verification Funnel Report: recipient is :both " \
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
                          "Verification Funnel Report NOT SENT"
        return nil
      end
      { to: to_emails, bcc: bcc_emails }
    end

    def send_verification_funnel_email(email_addresses:, report_reader:, agency_abbreviation:)
      ReportMailer.tables_report(
        to: email_addresses[:to],
        bcc: email_addresses[:bcc],
        subject: verification_funnel_email_subject(agency_abbreviation, report_reader),
        reports: report_reader.as_emailable_reports,
        message: verification_funnel_email_preamble,
        attachment_format: :csv,
      ).deliver_now
    end

    def verification_funnel_email_subject(agency_abbreviation, report_reader)
      if agency_abbreviation.blank?
        Rails.logger.warn 'Missing agency abbreviation'
        agency_abbreviation_formatted = ''
      else
        agency_abbreviation_formatted = "#{agency_abbreviation} "
      end

      # Get file date from S3, fallback to today
      report_date = get_report_file_date(report_reader)

      "#{agency_abbreviation_formatted}Verification Funnel Report "\
      "#{report_time_range_label_email_subject} - #{report_date}"
    end

    def get_report_file_date(report_reader)
      # We know files exist, so just get the first one
      file_name = report_reader.csv_file_names.first
      begin
        last_modified = report_reader.get_file_last_modified(file_name)
        last_modified.strftime('%Y-%m-%d')
      rescue Aws::S3::Errors::NoSuchKey
        # Shouldn't happen, but fallback gracefully
        Rails.logger.warn 'Unexpected S3 file access issue when getting modified date'\
                          ', using today for email subject'
        Date.current.strftime('%Y-%m-%d')
      end
    end

    def verification_funnel_email_preamble
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

    # Weeks are Sunday-Saturday to match the producer's all_week(:sunday); a
    # different week boundary here would resolve to a different S3 folder.
    def report_time_range
      anchor = @run_date.prev_day(@days_back_for_time_period)

      case @time_frame
      when 'daily'
        anchor.all_day
      when 'weekly'
        anchor.all_week(:sunday)
      when 'monthly'
        anchor.all_month
      when 'quarterly'
        anchor.all_quarter
      else
        raise ArgumentError, "Unsupported time frame: #{@time_frame}"
      end
    end

    # Mirrors Reports::VerificationFunnelReport#report_time_range_label in
    # reporting-rails
    #   daily     -> Jan012026 (Unused for now)
    #   weekly    -> 20260104_20260110
    #   monthly   -> Jan2026
    #   quarterly -> Q12026 (Unused for now)
    def report_time_range_label
      range = report_time_range
      end_of_range = range.end

      case @time_frame
      when 'daily'
        "#{end_of_range.strftime('%b')}#{end_of_range.strftime('%d')}"\
          "#{end_of_range.strftime('%Y')}"
      when 'weekly'
        "#{range.begin.strftime('%Y%m%d')}_#{end_of_range.strftime('%Y%m%d')}"
      when 'monthly'
        "#{end_of_range.strftime('%b')}#{end_of_range.strftime('%Y')}"
      when 'quarterly'
        q_int = ((end_of_range.month - 1) / 3) + 1
        "Q#{q_int}#{end_of_range.strftime('%Y')}"
      else
        raise ArgumentError, "Unsupported time frame: #{@time_frame}"
      end
    end

    def report_time_range_label_email_subject
      range = report_time_range
      end_of_range = range.end

      case @time_frame
      when 'daily'
        end_of_range.strftime('%b %-d %Y') # Jan 1 2026
      when 'weekly'
        "#{range.begin.strftime('%b %-d')} - #{end_of_range.strftime('%b %-d %Y')}"
      when 'monthly'
        end_of_range.strftime('%b %Y') # Jan 2026
      when 'quarterly'
        q_int = ((end_of_range.month - 1) / 3) + 1
        "Q#{q_int} CY #{end_of_range.year}" # Q1 CY 2026
      else
        raise ArgumentError, "Unsupported time frame: #{@time_frame}"
      end
    end

    def report_configs
      IdentityConfig.store.verification_funnel_s3_report_configs
    end

    def validate_parameters!
      unless @days_back_for_time_period.is_a?(Integer) && @days_back_for_time_period.between?(0, 90)
        raise ArgumentError, "days_back_for_time_period must be between 0 and 90,"\
                             " got #{@days_back_for_time_period}"
      end

      unless [:internal, :both].include?(@report_receiver)
        raise ArgumentError, "report_receiver must be :internal or :both, got #{@report_receiver}"
      end

      unless VALID_TIME_FRAMES.include?(@time_frame)
        raise ArgumentError, "time_frame must be one of #{VALID_TIME_FRAMES.join(', ')},"\
                             " got #{@time_frame}"
      end
    end

    def validate_config(config)
      if config['issuer_string'].blank?
        Rails.logger.error 'Missing issuer_string for config'
        return false
      end

      issuer_string = config['issuer_string']

      # Check that we'll have 1+ email to send to
      internal_emails = Array(config['internal_emails']).select(&:present?)
      partner_emails = Array(config['partner_emails']).select(&:present?)

      if internal_emails.empty? && partner_emails.empty?
        Rails.logger.error "No emails provided for issuer #{issuer_string}"
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
