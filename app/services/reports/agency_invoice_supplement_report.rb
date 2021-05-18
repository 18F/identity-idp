module Reports
  class AgencyInvoiceSupplementReport < BaseReport
    REPORT_NAME = 'agency-invoice-supplemement-report'.freeze

    IaaParts = Struct.new(:iaa, :date_range, :issuers, keyword_init: true)

    def call
      results = iaas.flat_map do |iaa|
        transaction_with_timeout { Db::SpCost::SpCostSummaryByIaa.call(iaa) }.to_a
      end

      save_report(REPORT_NAME, results.to_json)
    end

    # @return [Array<String>]
    def iaas
      ServiceProvider.
        distinct.
        where.not(iaa: nil).
        pluck(:iaa)
    end
end
