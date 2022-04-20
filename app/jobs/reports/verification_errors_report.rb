require 'identity/hostdata'
require 'csv'

module Reports
  class VerificationErrorsReport < BaseReport
    REPORT_NAME = 'verification-errors-report'.freeze

    include GoodJob::ActiveJobExtensions::Concurrency

    good_job_control_concurrency_with(
      total_limit: 1,
      key: -> { "#{REPORT_NAME}-#{arguments.first}" },
    )

    def perform(_date)
      csv_reports = []
      configs = IdentityConfig.store.verification_errors_report_configs
      configs.each do |report_hash|
        name = report_hash['name']
        issuers = report_hash['issuers']
        report = verification_errors_data_for_issuers(name, issuers)
        csv_reports << report
      end
      csv_reports
    end

    private

    def verification_errors_data_for_issuers(report_name, issuers)
      csv = CSV.new('', row_sep: "\r\n")
      csv << %w[uuid welcome_view_at error_code]
      issuers.each do |issuer|
        transaction_with_timeout do
          rows = ::VerificationErrorsReport.call(issuer, 24.hours.ago)
          rows.each do |row|
            csv << [row['uuid'], row['welcome_view_at'].iso8601, ial2_error_code(row)]
          end
        end
      end
      data = csv.string
      save_report(report_name, data, extension: 'csv')
      data
    end

    def ial2_error_code(row)
      welcome_at = row['welcome_view_at']
      verify_at = row['verify_submit_at']
      phone_at = row['verify_phone_submit_at']
      doc_at = row['document_capture_submit_at']
      encrypt_at = row['encrypt_view_at']
      ssn_at = row['ssn_view_at']
      info_at = row['enter_info_view_at']
      return 'PHONE_FAIL' if submit_failed?(welcome_at, phone_at, encrypt_at)
      return 'VERIFY_FAIL' if submit_failed?(welcome_at, verify_at, ssn_at)
      return 'DOCUMENT_FAIL' if submit_failed?(welcome_at, doc_at, info_at)
      'ABANDON'
    end

    def submit_failed?(welcome_at, submit_at, next_step_at)
      submit_at && submit_at >= welcome_at && (!next_step_at || next_step_at < submit_at)
    end
  end
end
