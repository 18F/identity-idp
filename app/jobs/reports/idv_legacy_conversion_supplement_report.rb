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
      sql = <<~SQL
        SELECT
	          iaa_orders.start_date
	        , iaa_orders.end_date
	        , iaa_orders.order_number
	        , iaa_gtcs.gtc_number AS gtc_number
	        , upgrade.issuer AS issuer
	        , sp.friendly_name AS friendly_name
	        , DATE_TRUNC('month', upgrade.upgraded_at) AS year_month
	        , COUNT(DISTINCT upgrade.user_id) AS user_count
        FROM iaa_orders
        INNER JOIN integration_usages iu ON iu.iaa_order_id = iaa_orders.id
        INNER JOIN integrations ON integrations.id = iu.integration_id
        INNER JOIN iaa_gtcs ON iaa_gtcs.id = iaa_orders.iaa_gtc_id
        INNER JOIN service_providers sp ON sp.issuer = integrations.issuer
        INNER JOIN (
          SELECT DISTINCT ON (user_id) *
          FROM sp_upgraded_biometric_profiles
        ) upgrade ON upgrade.issuer = integrations.issuer
        WHERE upgrade.upgraded_at BETWEEN iaa_orders.start_date AND iaa_orders.end_date
        GROUP BY iaa_orders.id, upgrade.issuer, year_month, iaa_gtcs.gtc_number, sp.friendly_name
        ORDER BY iaa_orders.id, year_month
      SQL

      results = transaction_with_timeout do
        ActiveRecord::Base.connection.select_all(sql)
      end

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
            IaaReportingHelper.key(
              gtc_number: iaa['gtc_number'],
              order_number: iaa['order_number'],
            ),
            iaa['start_date'],
            iaa['end_date'],
            iaa['issuer'],
            iaa['friendly_name'],
            iaa['year_month'].strftime('%Y%m'),
            iaa['year_month'].strftime('%B %Y'),
            iaa['user_count'],
          ]
        end
      end
    end
  end
end
