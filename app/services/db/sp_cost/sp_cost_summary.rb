module Db
  module SpCost
    class SpCostSummary
      def self.call(start, finish)
        params = {
          start: ActiveRecord::Base.connection.quote(start),
          finish: ActiveRecord::Base.connection.quote(finish),
        }

        sql = format(<<~SQL, params)
          SELECT sp_costs.issuer,sp_costs.ial,cost_type,MAX(app_id) AS app_id,COUNT(*)
          FROM sp_costs, service_providers
          WHERE %{start} <= sp_costs.created_at and sp_costs.created_at <= %{finish} AND
            sp_costs.issuer = service_providers.issuer
          GROUP BY sp_costs.issuer,sp_costs.ial,cost_type ORDER BY issuer,ial,cost_type
        SQL

        ActiveRecord::Base.connection.execute(sql)
      end
    end
  end
end
