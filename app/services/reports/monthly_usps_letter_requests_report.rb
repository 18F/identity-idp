require 'login_gov/hostdata'

module Reports
  class MonthlyUspsLetterRequestsReport < BaseReport
    REPORT_NAME = 'monthly-usps-letter-requests-report'.freeze

    def call
      daily_results = transaction_with_timeout do
        Db::LetterRequestsToUspsFtpLog::LettersSentInRange.call(first_of_this_month, end_of_today)
      end
      totals = calculate_totals(daily_results)
      save_report(REPORT_NAME, {total_letter_requests: totals,
                                daily_letter_requests: daily_results}.to_json)
    end

    private

    def calculate_totals(daily_results)
      daily_results.inject(0) {|sum, rec| sum + rec['letter_requests_count'].to_i }
    end
  end
end
