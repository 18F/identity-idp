require 'identity/hostdata'

module Reports
  class UniqueMonthlyAuthsReport < BaseReport
    REPORT_NAME = 'unique-monthly-auths-report'.freeze

    include GoodJob::ActiveJobExtensions::Concurrency

    good_job_control_concurrency_with(
      enqueue_limit: 1,
      perform_limit: 1,
      key: -> { "#{REPORT_NAME}-#{arguments.first}" },
    )

    def perform(_date)
      auth_counts = transaction_with_timeout do
        Db::MonthlySpAuthCount::UniqueMonthlyAuthCounts.call
      end
      save_report(REPORT_NAME, auth_counts.to_json, extension: 'json')
    end
  end
end
