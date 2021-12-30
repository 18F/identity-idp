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
      total_ial1_count = 0
      total_ial2_count = 0
      total_count = 0
      user_counts.each do |hash|
        ial1_count = hash['ial1_total'].to_i
        ial2_count = hash['ial2_total'].to_i
        count = hash['total'].to_i
        track_report_data_event(
          Analytics::REPORT_SP_USER_COUNTS,
          issuer: hash['issuer'],
          user_total: count,
          ial1_user_total: ial1_count,
          ial2_user_total: ial2_count,
          app_id: hash['app_id'].to_s,
        )
        total_ial1_count += ial1_count
        total_ial2_count += ial2_count
        total_count += count
      end

      track_report_data_event(
        Analytics::REPORT_TOTAL_SP_USER_COUNTS,
        user_total: total_count,
        ial1_user_total: total_ial1_count,
        ial2_user_total: total_ial2_count,
      )
    end
  end
end
