# frozen_string_literal: true

require 'csv'

module Reports
  class IdvLegacyConversionSupplementReport < BaseReport
    REPORT_NAME = 'idv-legacy-conversion-supplement-report'

    def perform(_date)
      csv = build_csv
      save_report(REPORT_NAME, csv, extension: 'csv')
    end

    # @param [Array<IaaReportingHelper::IaaConfig>] iaas
    # @param [Array<IaaReportingHelper::PartnerConfig>] partner_accounts
    # @return [String] CSV report
    def build_csv
      results = Agreements::IaaOrder.joins(:integrations, :iaa_gtc).joins(
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
          DATE_TRUNC('month', sp.upgraded_at) AS year_month,
          count(distinct sp.user_id) AS user_count
        SQL
      ).group('iaa_orders.id, sp.issuer, year_month, iaa_gtcs.gtc_number').
        order('iaa_orders.id, year_month')

      CSV.generate do |csv|
        csv << [
          'iaa_order_number',
          'iaa_start_date',
          'iaa_end_date',
          'issuer',
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
