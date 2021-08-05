require 'identity/hostdata'

module Reports
  class SpUserCountsReport < BaseReport
    REPORT_NAME = 'sp-user-counts-report'.freeze

    include GoodJob::ActiveJobExtensions::Concurrency

    good_job_control_concurrency_with(
      enqueue_limit: 1,
      perform_limit: 1,
      key: -> { "#{REPORT_NAME}-#{arguments.first}" },
    )

    def perform(_date)
      user_counts = transaction_with_timeout do
        Db::Identity::SpUserCounts.call
      end
      save_report(REPORT_NAME, user_counts.to_json, extension: 'json')
    end
  end
end
