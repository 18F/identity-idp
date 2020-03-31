module Db
  module SpCost
    class TotalSpCostSummary
      def self.call(start, finish)
        params = {
          start: ActiveRecord::Base.connection.quote(start),
          finish: ActiveRecord::Base.connection.quote(finish),
        }

        sql = format(<<~SQL, params)
          SELECT cost_type,COUNT(*)
          FROM sp_costs
          WHERE %{start} <= created_at and created_at <= %{finish}
          GROUP BY cost_type ORDER BY cost_type
        SQL
        ActiveRecord::Base.connection.execute(sql)
      end
    end
  end
end
