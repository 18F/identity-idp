require 'identity/hostdata'

module Reports
  class UniqueMonthlyAuthsReport < BaseReport
    REPORT_NAME = 'unique-monthly-auths-report'.freeze

    def call
      auth_counts =
        transaction_with_timeout { Db::MonthlySpAuthCount::UniqueMonthlyAuthCounts.call }
      save_report(REPORT_NAME, auth_counts.to_json)
    end
  end
end
