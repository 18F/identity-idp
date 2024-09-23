# frozen_string_literal: true

require 'csv'

module Reports
  class IdvLegacyConversionSupplementReport < BaseReport
    REPORT_NAME = 'idv-legacy-conversion-supplement-report'

    def perform(_date)
      csv = build_csv
      save_report(REPORT_NAME, csv, extension: 'csv')
    end

    # @return [String] CSV report
    def build_csv
      results = Agreements::IaaOrder.joins(integrations: :service_provider).joins(:iaa_gtc).
        joins(
          <<-SQL,
            INNER JOIN (
              SELECT DISTINCT ON (user_id) *
              FROM sp_upgraded_biometric_profiles
            ) sp ON sp.issuer = integrations.issuer
          SQL
        ).select(
          <<-SQL,
            iaa_orders.*,
            iaa_gtcs.gtc_number AS gtc_number,
            sp.issuer AS issuer,
            service_providers.friendly_name AS friendly_name,
            DATE_TRUNC('month', sp.upgraded_at) AS year_month,
            count(distinct sp.user_id) AS user_count
          SQL
        ).where(
          'sp.upgraded_at BETWEEN iaa_orders.start_date AND iaa_orders.end_date',
        ).group('iaa_orders.id, sp.issuer, year_month, iaa_gtcs.gtc_number,
          service_providers.friendly_name').
        order('iaa_orders.id, year_month')

      CSV.generate do |csv|
        csv << [
          'iaa_order_number',
          'iaa_start_date',
          'iaa_end_date',
          'issuer',
          'friendly_name',
          'year_month',
          'year_month_readable',
          'user_count',
        ]

        results.each do |iaa|
          csv << [
            "#{iaa.gtc_number}-#{format('%04d', iaa.order_number)}",
            iaa.start_date,
            iaa.end_date,
            iaa.issuer,
            iaa.friendly_name,
            iaa.year_month.strftime('%Y%m'),
            iaa.year_month.strftime('%B %Y'),
            iaa.user_count,
          ]
        end
      end
    end

    def extract(arr, key, ial:)
      arr.find { |elem| elem[:ial] == ial && elem[key] }&.dig(key) || 0
    end
  end
end
