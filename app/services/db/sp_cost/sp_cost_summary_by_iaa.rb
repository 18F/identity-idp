module Db
  module SpCost
    class SpCostSummaryByIaa
      # @param [String] iaa
      # @param [Range<Date>] iaa_range
      def self.call(iaa:, iaa_range:)
        params = {
          iaa: iaa,
          iaa_start_date: iaa_range.begin,
          iaa_end_date: iaa_range.end,
        }.transform_values { |v| ActiveRecord::Base.connection.quote(v) }

        sql = format(<<~SQL, params)
          SELECT
            sp_costs.issuer
          , sp_costs.ial
          , sp_costs.cost_type
          , MAX(service_providers.iaa) AS iaa
          , MAX(service_providers.app_id) AS app_id
          , COUNT(*)
          FROM
            sp_costs
          INNER JOIN service_providers ON sp_costs.issuer = service_providers.issuer
          WHERE
            service_providers.iaa = %{iaa}
            AND sp_costs.created_at BETWEEN %{iaa_start_date} AND %{iaa_end_date}
          GROUP BY
            sp_costs.issuer
          , sp_costs.ial
          , cost_type
          ORDER BY
            issuer
          , ial
          , cost_type
        SQL

        ActiveRecord::Base.connection.execute(sql).to_a
      end
    end
  end
end
