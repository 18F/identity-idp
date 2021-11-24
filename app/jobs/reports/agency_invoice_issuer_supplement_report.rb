module Reports
  class AgencyInvoiceIssuerSupplementReport < BaseReport
    REPORT_NAME = 'agency-invoice-issuer-supplemement-report'.freeze

    include GoodJob::ActiveJobExtensions::Concurrency

    good_job_control_concurrency_with(
      total_limit: 1,
      key: -> { "#{REPORT_NAME}-#{arguments.first}" },
    )

    def perform(_date)
      raw_results = service_providers.flat_map do |service_provider|
        transaction_with_timeout do
          Db::MonthlySpAuthCount::TotalMonthlyAuthCountsWithinIaaWindow.call(
            issuer: service_provider.issuer,
            iaa_start_date: service_provider.iaa_start_date,
            iaa_end_date: service_provider.iaa_end_date,
            iaa: service_provider.iaa,
          )
        end
      end

      results = combine_by_issuer_month(raw_results)

      save_report(REPORT_NAME, results.to_json, extension: 'json')
    end

    def service_providers
      ServiceProvider.
        where.not(iaa_start_date: nil).
        where.not(iaa_end_date: nil).
        to_a
    end

    # Turns ial1/ial2 rows into ial1/ial2 columns
    def combine_by_issuer_month(raw_results)
      raw_results.group_by { |r| [r[:issuer], r[:year_month]] }.
        transform_values do |grouped|
          issuer = grouped.first[:issuer]
          iaa = grouped.first[:iaa]
          iaa_start_date = grouped.first[:iaa_start_date]
          iaa_end_date = grouped.first[:iaa_end_date]
          year_month = grouped.first[:year_month]

          {
            issuer: issuer,
            iaa: iaa,
            iaa_start_date: iaa_start_date,
            iaa_end_date: iaa_end_date,
            year_month: year_month,
            ial1_total_auth_count: extract(grouped, :total_auth_count, ial: 1),
            ial2_total_auth_count: extract(grouped, :total_auth_count, ial: 2),
            ial1_unique_users: extract(grouped, :unique_users, ial: 1),
            ial2_unique_users: extract(grouped, :unique_users, ial: 2),
          }
        end.values
    end

    def extract(arr, key, ial:)
      arr.find { |elem| elem[:ial] == ial && elem[key] }&.dig(key) || 0
    end
  end
end
