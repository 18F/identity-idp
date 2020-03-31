module Db
  module SpCost
    class SpCostSummary
      def self.call(start, finish)
        params = {
          start: ActiveRecord::Base.connection.quote(start),
          finish: ActiveRecord::Base.connection.quote(finish),
        }

        sql = format(<<~SQL, params)
          SELECT issuer,ial,cost_type,COUNT(*)
          FROM sp_costs
          WHERE %{start} <= created_at and created_at <= %{finish}
          GROUP BY issuer,ial,cost_type ORDER BY issuer,ial,cost_type
        SQL
        ActiveRecord::Base.connection.execute(sql)
      end
    end
  end
end
