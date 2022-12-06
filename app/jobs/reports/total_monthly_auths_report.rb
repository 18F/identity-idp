require 'identity/hostdata'

module Reports
  class TotalMonthlyAuthsReport < BaseReport
    REPORT_NAME = 'total-monthly-auths-report'.freeze

    include GoodJob::ActiveJobExtensions::Concurrency

    good_job_control_concurrency_with(
      total_limit: 1,
      key: -> { "#{REPORT_NAME}-#{arguments.first}" },
    )

    def perform(_date)
      auth_counts = Db::MonthlySpAuthCount::TotalMonthlyAuthCounts.call
      save_report(REPORT_NAME, auth_counts.to_json, extension: 'json')
    end
  end
end
