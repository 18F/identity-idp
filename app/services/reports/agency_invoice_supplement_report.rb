module Reports
  class AgencyInvoiceSupplementReport < BaseReport
    REPORT_NAME = 'agency-invoice-supplemement-report'.freeze

    def call
      results = iaas.flat_map do |iaa|
        transaction_with_timeout do
          Db::MonthlySpAuthCost::UniqueMonthlyAuthCountsByIaa.call(iaa)
        end.to_a
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
end
