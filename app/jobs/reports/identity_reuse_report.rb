require 'identity/hostdata'

module Reports
  class IdentityReuseReport < BaseReport
    REPORT_NAME = 'credential-reuse-report'.freeze

    include GoodJob::ActiveJobExtensions::Concurrency

    good_job_control_concurrency_with(
      total_limit: 1,
      key: -> { "#{REPORT_NAME}-#{arguments.first}" },
    )

    def perform(_date)
      report = {
        total_ial1_identity_counts: ial1_identity_counts,
        total_unique_ial1_identity_counts: unique_ial1_identity_counts,
        total_ial2_identity_counts: ial2_identity_counts,
        total_unique_ial2_identity_counts: unique_ial2_identity_counts,
      }
      track_report_data_event('Report Identity Reuse Counts', report)
      save_report(REPORT_NAME, report.to_json, extension: 'json')
    end

    private

    def ial1_identity_counts
      transaction_with_timeout do
        return Db::Identity::TotalIdentitiesPerIalCount.call(1)
      end
    end

    def ial2_identity_counts
      transaction_with_timeout do
        return Db::Identity::TotalIdentitiesPerIalCount.call(2)
      end
    end

    def unique_ial1_identity_counts
      transaction_with_timeout do
        return Db::Identity::UniqueIdentitiesPerIalCount.call(1)
      end
    end

    def unique_ial2_identity_counts
      transaction_with_timeout do
        return Db::Identity::UniqueIdentitiesPerIalCount.call(2)
      end
    end
  end
end
