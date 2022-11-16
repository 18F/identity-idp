require 'identity/hostdata'

module Reports
  class MonthlyGpoLetterRequestsReport < BaseReport
    REPORT_NAME = 'monthly-usps-letter-requests-report'.freeze

    include GoodJob::ActiveJobExtensions::Concurrency

    good_job_control_concurrency_with(
      total_limit: 1,
      key: -> { "#{REPORT_NAME}-#{arguments.first}" },
    )

    def perform(_date, start_time: first_of_this_month, end_time: end_of_today)
      daily_results = transaction_with_timeout do
        ::LetterRequestsToGpoFtpLog.where(ftp_at: start_time..end_time)
      end
      totals = calculate_totals(daily_results)
      save_report(
        REPORT_NAME,
        {
          total_letter_requests: totals,
          daily_letter_requests: daily_results,
        }.to_json,
        extension: 'json',
      )
    end

    private

    def calculate_totals(daily_results)
      daily_results.inject(0) { |sum, rec| sum + rec['letter_requests_count'].to_i }
    end
  end
end
