module Reports
  class AgencyInvoiceIaaSupplementReport < BaseReport
    REPORT_NAME = 'agency-invoice-iaa-supplemement-report'.freeze

    def call
      raw_results = iaas.flat_map do |iaa|
        [:sum, :unique, :new_unique].flat_map do |aggregate|
          transaction_with_timeout do
            Db::MonthlySpAuthCount::UniqueMonthlyAuthCountsByIaa.call(
              iaa: iaa,
              aggregate: aggregate,
            )
          end.to_a
        end
      end

      results = combine_by_iaa_month(raw_results)

      save_report(REPORT_NAME, results.to_json, extension: 'json')
    end

    # @return [Array<Hash>]
    def iaas
      Agreements::IaaGtc.
        includes(iaa_orders: { integration_usages: :integration }).
        flat_map do |gtc|
          gtc.iaa_orders.flat_map do |iaa_order|
            key = "#{gtc.gtc_number}-#{format('%04d', iaa_order.order_number)}"
            issuers = iaa_order.integration_usages.map { |usage| usage.integration.issuer }

            if issuers.present?
              {
                key: key,
                issuers: issuers,
                start_date: gtc.start_date,
                end_date: gtc.end_date,
              }
            end
          end.compact
        end
      # GTC number + order number
    end

    # Turns ial1/ial2 rows into ial1/ial2 columns
    def combine_by_iaa_month(raw_results)
      raw_results.group_by { |r| [r['key'], r['year_month']] }.
        transform_values do |grouped|
          key = grouped.first['key']
          iaa_start_date = grouped.first['iaa_start_date']
          iaa_end_date = grouped.first['iaa_end_date']
          year_month = grouped.first['year_month']

          {
            iaa: key,
            iaa_start_date: iaa_start_date,
            iaa_end_date: iaa_end_date,
            year_month: year_month,
            ial1_total_auth_count: extract(grouped, 'total_auth_count', ial: 1),
            ial2_total_auth_count: extract(grouped, 'total_auth_count', ial: 2),
            ial1_unique_users: extract(grouped, 'unique_users', ial: 1),
            ial2_unique_users: extract(grouped, 'unique_users', ial: 2),
            ial1_new_unique_users: extract(grouped, 'new_unique_users', ial: 1),
            ial2_new_unique_users: extract(grouped, 'new_unique_users', ial: 2),
          }
        end.values
    end

    def extract(arr, key, ial:)
      arr.find { |elem| elem['ial'] == ial && elem[key] }&.dig(key) || 0
    end
  end
end
