require 'identity/hostdata'

module Reports
  class DocAuthFunnelReport < BaseReport
    REPORT_NAME = 'doc-auth-funnel-report'.freeze

    include GoodJob::ActiveJobExtensions::Concurrency

    good_job_control_concurrency_with(
      total_limit: 1,
      key: -> { "#{REPORT_NAME}-#{arguments.first}" },
    )

    def perform(_date)
      report = transaction_with_timeout do
        Db::DocAuthLog::DocAuthFunnelSummaryStats.new.call
      end
      save_report(REPORT_NAME, report.to_json, extension: 'json')
    end
  end
end
