module Reports
  class AgencyInvoiceSupplementReport < BaseReport
    REPORT_NAME = 'agency-invoice-supplemement-report'.freeze

    def call
      raw_results = iaas.flat_map do |iaa|
        transaction_with_timeout do
          Db::MonthlySpAuthCount::UniqueMonthlyAuthCountsByIaa.call(iaa)
        end.to_a
      end

      results = combine_by_iaa_month(raw_results)

      save_report(REPORT_NAME, results.to_json)
    end

    # @return [Array<String>]
    def iaas
      ServiceProvider.
        distinct.
        where.not(iaa: nil).
        pluck(:iaa)
    end

    # Turns ial1/ial2 rows into ial1/ial2 columns
    def combine_by_iaa_month(raw_results)
      raw_results.group_by { |r| [r['iaa'], r['year_month']] }.
        transform_values do |grouped|
          iaa = grouped.first['iaa']
          iaa_start_date = grouped.first['iaa_start_date']
          iaa_end_date = grouped.first['iaa_end_date']
          year_month = grouped.first['year_month']

          ial1_unique_count = grouped.find { |r| r['ial'] == 1 }&.dig('unique_users') || 0
          ial2_unique_count = grouped.find { |r| r['ial'] == 2 }&.dig('unique_users') || 0

          {
            iaa: iaa,
            iaa_start_date: iaa_start_date,
            iaa_end_date: iaa_end_date,
            year_month: year_month,
            ial1_unique_count: ial1_unique_count,
            ial2_unique_count: ial2_unique_count,
          }
        end.values
    end
  end
end
