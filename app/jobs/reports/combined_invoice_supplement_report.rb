require 'csv'

module Reports
  class CombinedInvoiceSupplementReport < BaseReport
    REPORT_NAME = 'combined-invoice-supplement-report'.freeze

    def perform(_date)
      iaas = IaaReportingHelper.iaas

      by_iaa_results = iaas.flat_map do |iaa|
        Db::MonthlySpAuthCount::UniqueMonthlyAuthCountsByIaa.call(
          key: iaa.key,
          issuers: iaa.issuers,
          start_date: iaa.start_date,
          end_date: iaa.end_date,
        )
      end

      by_issuer_results = iaas.flat_map do |iaa|
        iaa.issuers.flat_map do |issuer|
          Db::MonthlySpAuthCount::TotalMonthlyAuthCountsWithinIaaWindow.call(
            issuer: issuer,
            iaa_start_date: iaa.start_date,
            iaa_end_date: iaa.end_date,
            iaa: iaa.key,
          )
        end
      end

      csv = combine_by_iaa_month(
        by_iaa_results: by_iaa_results,
        by_issuer_results: by_issuer_results,
      )

      save_report(REPORT_NAME, csv, extension: 'csv')
    end

    def combine_by_iaa_month(by_iaa_results:, by_issuer_results:)
      by_iaa_and_year_month = by_iaa_results.group_by do |result|
        [result[:key], result[:year_month]]
      end

      by_issuer_iaa_issuer_year_months = by_issuer_results.
        group_by { |r| r[:iaa] }.
        transform_values do |iaa|
          iaa.group_by { |r| r[:issuer] }.
            transform_values { |issuer| issuer.group_by { |r| r[:year_month] } }
        end

      # rubocop:disable Metrics/BlockLength
      CSV.generate do |csv|
        csv << [
          'iaa_order_number',
          'iaa_start_date',
          'iaa_end_date',

          'issuer',
          'friendly_name',

          'year_month',
          'year_month_readable',

          'iaa_ial1_unique_users',
          'iaa_ial2_unique_users',
          'iaa_ial1_plus_2_unique_users',
          'iaa_ial2_new_unique_users',

          'issuer_ial1_total_auth_count',
          'issuer_ial2_total_auth_count',
          'issuer_ial1_plus_2_total_auth_count',

          'issuer_ial1_unique_users',
          'issuer_ial2_unique_users',
          'issuer_ial1_plus_2_unique_users',
          'issuer_ial2_new_unique_users',
        ]

        by_issuer_iaa_issuer_year_months.each do |iaa_key, issuer_year_months|
          issuer_year_months.each do |issuer, year_months_data|
            friendly_name = ServiceProvider.find_by(issuer: issuer).friendly_name
            year_months = year_months_data.keys.sort

            year_months.each do |year_month|
              iaa_results = by_iaa_and_year_month[ [iaa_key, year_month] ]
              issuer_results = year_months_data[year_month]

              year_month_start = Date.strptime(year_month, '%Y%m')
              iaa_start_date = Date.parse(iaa_results.first[:iaa_start_date])
              iaa_end_date = Date.parse(iaa_results.first[:iaa_end_date])

              csv << [
                iaa_key,
                iaa_start_date,
                iaa_end_date,

                issuer,
                friendly_name,

                year_month,
                year_month_start.strftime('%B %Y'),

                (iaa_ial1_unique_users = extract(iaa_results, :unique_users, ial: 1)),
                (iaa_ial2_unique_users = extract(iaa_results, :unique_users, ial: 2)),
                iaa_ial1_unique_users + iaa_ial2_unique_users,
                extract(iaa_results, :new_unique_users, ial: 2),

                (ial1_total_auth_count = extract(issuer_results, :total_auth_count, ial: 1)),
                (ial2_total_auth_count = extract(issuer_results, :total_auth_count, ial: 2)),
                ial1_total_auth_count + ial2_total_auth_count,

                (issuer_ial1_unique_users = extract(issuer_results, :unique_users, ial: 1)),
                (issuer_ial2_unique_users = extract(issuer_results, :unique_users, ial: 2)),
                issuer_ial1_unique_users + issuer_ial2_unique_users,
                extract(issuer_results, :new_unique_users, ial: 2),
              ]
            end
          end
        end
      end
      # rubocop:enable Metrics/BlockLength
    end

    def extract(arr, key, ial:)
      arr.find { |elem| elem[:ial] == ial && elem[key] }&.dig(key) || 0
    end
  end
end
