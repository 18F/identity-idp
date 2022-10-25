require 'identity/hostdata'

module Reports
  class UniqueMonthlyAuthsReport < BaseReport
    REPORT_NAME = 'unique-monthly-auths-report'.freeze

    def perform(_date)
      auth_counts = transaction_with_timeout do
        Db::MonthlySpAuthCount::UniqueMonthlyAuthCounts.call
      end
      save_report(REPORT_NAME, auth_counts.to_json, extension: 'json')
    end
  end
end
