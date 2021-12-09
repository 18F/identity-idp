require 'csv'

module Reports
  class AgreementSummaryReport < BaseReport
    REPORT_NAME = 'agreement-summary-report'.freeze

    include GoodJob::ActiveJobExtensions::Concurrency

    good_job_control_concurrency_with(
      total_limit: 1,
      key: -> { "#{REPORT_NAME}-#{arguments.first}" },
    )

    def perform(_date)
      csv = build_report

      save_report(REPORT_NAME, csv, extension: 'csv')
    end

    # @return [String]
    def build_report
      CSV.generate do |csv|
        csv << %w[
          gtc_number
          order_number
          issuer
          friendly_name
          start_date
          end_date
        ]

        IaaReportingHelper.iaas.each do |iaa|
          ServiceProvider.where(issuer: iaa.issuers).order(:issuer).each do |service_provider|
            csv << [
              iaa.gtc_number,
              iaa.order_number,
              service_provider.issuer,
              service_provider.friendly_name,
              iaa.start_date,
              iaa.end_date,
            ]
          end
        end
      end
    end
  end
end
