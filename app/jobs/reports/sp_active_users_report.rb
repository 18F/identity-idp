require 'identity/hostdata'

module Reports
  class SpActiveUsersReport < BaseReport
    REPORT_NAME = 'sp-active-users-report'.freeze

    include GoodJob::ActiveJobExtensions::Concurrency

    good_job_control_concurrency_with(
      total_limit: 1,
      key: -> { "#{REPORT_NAME}-#{arguments.first}" },
    )

    def perform(_date)
      results = transaction_with_timeout do
        Db::Identity::SpActiveUserCounts.call(fiscal_start_date)
      end
      save_report(REPORT_NAME, results.to_json, extension: 'json')
    end
  end
end
