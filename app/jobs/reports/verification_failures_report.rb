require 'identity/hostdata'
require 'csv'
require 'fugit'

module Reports
  class VerificationFailuresReport < BaseReport
    REPORT_NAME = 'verification-failures-report'.freeze

    def perform(date)
      csv_reports = []
      configs = IdentityConfig.store.verification_errors_report_configs
      configs.each do |report_hash|
        name = report_hash['name']
        issuers = report_hash['issuers']
        report = verification_errors_data_for_issuers(date, name, issuers)
        csv_reports << report
      end
      csv_reports
    end

    private

    def verification_errors_data_for_issuers(date, report_name, issuers)
      csv = CSV.new('', row_sep: "\r\n")
      csv << %w[uuid welcome_view_at error_code]
      issuers.each do |issuer|
        transaction_with_timeout do
          rows = ::VerificationFailuresReport.call(
            issuer,
            (date.beginning_of_day - 1).beginning_of_day,
            date.beginning_of_day,
          )
          rows.each do |row|
            csv << [row['uuid'], row['welcome_view_at'].iso8601, ial2_error_code(row)]
          end
        end
      end
      data = csv.string
      save_report("#{REPORT_NAME}/#{report_name}", data, extension: 'csv')
      data
    end

    def ial2_error_code(row)
      welcome_at = row['welcome_view_at']
      verify_at = row['verify_submit_at']
      phone_submit_at = row['verify_phone_submit_at']
      encrypt_at = row['encrypt_view_at']
      ssn_at = row['ssn_view_at']
      phone_view_at = row['verify_phone_view_at']
      return 'PHONE_FAIL' if submit_failed?(welcome_at, phone_submit_at, encrypt_at)
      return 'VERIFY_FAIL' if submit_failed?(welcome_at, verify_at, phone_view_at)
      if submit_failed?(welcome_at, row['document_capture_submit_at'], ssn_at) ||
         submit_failed?(welcome_at, row['back_image_submit_at'], ssn_at) ||
         submit_failed?(welcome_at, row['capture_mobile_back_image_submit_at'], ssn_at) ||
         submit_failed?(welcome_at, row['mobile_back_image_submit_at'], ssn_at)
        return 'DOCUMENT_FAIL'
      end
      'ABANDON'
    end

    def submit_failed?(welcome_at, submit_at, next_step_at)
      good_job_cron = Rails.application.config.good_job.cron
      cron_entry = good_job_cron.values.find { |c| c[:class] == self.class.name }&.[](:cron)
      interval = cron_entry ? (Fugit.parse(cron_entry).rough_frequency - 3600).seconds : 23.hours
      return unless submit_at # need a submit
      return unless (submit_at + interval) >= welcome_at # need to be in range
      return true unless next_step_at # submit must have failed if we did not get to next step
      (submit_at + interval) > next_step_at
    end
  end
end
