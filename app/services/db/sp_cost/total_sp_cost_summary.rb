module Db
  module SpCost
    class TotalSpCostSummary
      def self.call
        sql = <<~SQL
          SELECT cost_type,COUNT(*)
          FROM sp_costs
          GROUP BY cost_type ORDER BY cost_type
        SQL
        ActiveRecord::Base.connection.execute(sql)
      end
    end
  end
end
