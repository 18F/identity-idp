require 'identity/hostdata'

module Reports
  class SpUserCountsReport < BaseReport
    REPORT_NAME = 'sp-user-counts-report'.freeze

    include GoodJob::ActiveJobExtensions::Concurrency

    good_job_control_concurrency_with(
      total_limit: 1,
      key: -> { "#{REPORT_NAME}-#{arguments.first}" },
    )

    def perform(_date)
      user_counts = transaction_with_timeout do
        Db::Identity::SpUserCounts.call
      end

      track_report_data_events(user_counts)
      save_report(REPORT_NAME, user_counts.to_json, extension: 'json')
    end

    private

    def track_report_data_events(user_counts)
      user_counts.each do |hash|
        track_report_data_event(
          Analytics::REPORT_SP_USER_COUNTS,
          issuer: hash['issuer'],
          user_total: hash['total'],
          ial1_user_total: hash['ial1_total'],
          ial2_user_total: hash['ial2_total'],
          app_id: hash['app_id'].to_s,
        )
      end
    end
  end
end
