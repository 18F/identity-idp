module Reports
  class AgencyInvoiceIaaSupplementReport < BaseReport
    REPORT_NAME = 'agency-invoice-iaa-supplemement-report'.freeze

    include GoodJob::ActiveJobExtensions::Concurrency

    good_job_control_concurrency_with(
      total_limit: 1,
      key: -> { "#{REPORT_NAME}-#{arguments.first}" },
    )

    def perform(_date)
      raw_results = IaaReportingHelper.iaas.flat_map do |iaa|
        Db::MonthlySpAuthCount::UniqueMonthlyAuthCountsByIaa.call(
          key: iaa.key,
          issuers: iaa.issuers,
          start_date: iaa.start_date,
          end_date: iaa.end_date,
        )
      end

      results = combine_by_iaa_month(raw_results)

      save_report(REPORT_NAME, results.to_json, extension: 'json')
    end

    # Turns ial1/ial2 rows into ial1/ial2 columns
    def combine_by_iaa_month(raw_results)
      raw_results.group_by { |r| [r[:key], r[:year_month]] }.
        transform_values do |grouped|
          key = grouped.first[:key]
          iaa_start_date = grouped.first[:iaa_start_date]
          iaa_end_date = grouped.first[:iaa_end_date]
          year_month = grouped.first[:year_month]

          {
            iaa: key,
            iaa_start_date: iaa_start_date,
            iaa_end_date: iaa_end_date,
            year_month: year_month,
            ial1_total_auth_count: extract(grouped, :total_auth_count, ial: 1),
            ial2_total_auth_count: extract(grouped, :total_auth_count, ial: 2),
            ial1_unique_users: extract(grouped, :unique_users, ial: 1),
            ial2_unique_users: extract(grouped, :unique_users, ial: 2),
            ial1_new_unique_users: extract(grouped, :new_unique_users, ial: 1),
            ial2_new_unique_users: extract(grouped, :new_unique_users, ial: 2),
          }
        end.values
    end

    def extract(arr, key, ial:)
      arr.find { |elem| elem[:ial] == ial && elem[key] }&.dig(key) || 0
    end
  end
end
