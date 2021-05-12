module Reports
  class AgencyInvoiceSupplementReport < BaseReport
    REPORT_NAME = 'agency-invoice-supplemement-report'.freeze

    def call
      iaa_start_ends = ServiceProvider.distinct.
        where.not(iaa: nil).
        pluck(:iaa, :iaa_start_date, :iaa_end_date)

      results = iaa_start_ends.flat_map do |iaa, iaa_start_date, iaa_end_date|
        transaction_with_timeout do
          Db::SpCost::SpCostSummaryByIaa.call(
            iaa: iaa,
            iaa_range: iaa_start_date..iaa_end_date,
          )
        end
      end

      save_report(REPORT_NAME, results.to_json)
    end
  end
end
