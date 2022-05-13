require 'identity/hostdata'

module Reports
  class IdentityReuseReport < BaseReport
    REPORT_NAME = 'credential-reuse-report'.freeze

    include GoodJob::ActiveJobExtensions::Concurrency

    good_job_control_concurrency_with(
      total_limit: 1,
      key: -> { "#{REPORT_NAME}-#{arguments.first}" },
    )

    def perform(date)
      report = {
        total_ial1_identity_counts: ial1_identity_counts(date),
        total_unique_ial1_identity_counts: unique_ial1_identity_counts(date),
        total_ial2_identity_counts: ial2_identity_counts(date),
        total_unique_ial2_identity_counts: unique_ial2_identity_counts(date),
      }
      track_report_data_event('Report Identity Reuse Counts', report)
      save_report(REPORT_NAME, report.to_json, extension: 'json')
    end

    private

    def ial1_identity_counts(date)
      transaction_with_timeout do
        Db::Identity::TotalIdentitiesPerIalCount.call(1, date)
      end
    end

    def ial2_identity_counts(date)
      transaction_with_timeout do
        Db::Identity::TotalIdentitiesPerIalCount.call(2, date)
      end
    end

    def unique_ial1_identity_counts(date)
      transaction_with_timeout do
        Db::Identity::UniqueIdentitiesPerIalCount.call(1, date)
      end
    end

    def unique_ial2_identity_counts(date)
      transaction_with_timeout do
        Db::Identity::UniqueIdentitiesPerIalCount.call(2, date)
      end
    end
  end
end
