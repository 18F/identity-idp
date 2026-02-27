# frozen_string_literal: true

module Reports
  class SpCredMetricsReportOrchestrator < BaseReport
    def perform(perform_date = Time.zone.yesterday.end_of_day, perform_receiver = :internal)
      GoodJob::Batch.enqueue do
        IdentityConfig.store.sp_monthly_cred_metric_report_configs.each do |report_config|
          Reports::SpCredMetricsReport.perform_later(
            perform_date,
            perform_receiver,
            report_config,
          )
        end
      end
    end
  end
end
