# frozen_string_literal: true

require 'identity/hostdata'

module Reports
  class TotalMonthlyAuthsReport < BaseReport
    REPORT_NAME = 'total-monthly-auths-report'

    def perform(_date)
      auth_counts = Db::MonthlySpAuthCount::TotalMonthlyAuthCounts.call
      save_report(REPORT_NAME, auth_counts.to_json, extension: 'json')
    end
  end
end
