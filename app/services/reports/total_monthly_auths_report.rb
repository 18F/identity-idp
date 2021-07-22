require 'identity/hostdata'

module Reports
  class TotalMonthlyAuthsReport < BaseReport
    REPORT_NAME = 'total-monthly-auths-report'.freeze

    def call
      auth_counts = transaction_with_timeout do
        Db::MonthlySpAuthCount::TotalMonthlyAuthCounts.call
      end
      save_report(REPORT_NAME, auth_counts.to_json, extension: 'json')
    end
  end
end
