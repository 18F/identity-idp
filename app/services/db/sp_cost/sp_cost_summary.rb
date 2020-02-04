module Db
  module SpCost
    class SpCostSummary
      def self.call(start, finish)
        sql = <<~SQL
          SELECT issuer,ial,cost_type,COUNT(*)
          FROM sp_costs
          WHERE '#{start}' <= created_at and created_at <= '#{finish}'
          GROUP BY issuer,ial,cost_type ORDER BY issuer,ial,cost_type
        SQL
        ActiveRecord::Base.connection.execute(sql)
      end
    end
  end
end
