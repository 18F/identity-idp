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
      results = save_report(REPORT_NAME, user_counts.to_json, extension: 'json')

      track_global_user_total_events
      results
    end

    private

    def track_report_data_events(user_counts)
      user_counts.each do |hash|
        track_report_data_event(
          'Report SP User Counts',
          issuer: hash['issuer'],
          user_total: hash['total'],
          ial1_user_total: hash['ial1_total'],
          ial2_user_total: hash['ial2_total'],
          app_id: hash['app_id'].to_s,
        )
      end
    end

    def track_global_user_total_events
      track_global_registered_users
      track_users_linked_to_sps(ial: 1, event: 'Report IAL1 Users Linked to SPs Count')
      track_users_linked_to_sps(ial: 2, event: 'Report IAL2 Users Linked to SPs Count')
    end

    def track_global_registered_users
      transaction_with_timeout do
        track_report_data_event(
          'Report Registered Users Count',
          count: Funnel::Registration::TotalRegisteredCount.call,
        )
      end
    end

    def track_users_linked_to_sps(ial:, event:)
      transaction_with_timeout do
        track_report_data_event(
          event,
          count: ServiceProviderIdentity.consented.where(ial: ial).select(:user_id).distinct.count,
        )
      end
    end
  end
end
