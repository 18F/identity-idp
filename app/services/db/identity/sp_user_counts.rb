module Db
  module Identity
    class SpUserCounts
      def self.call
        sql = <<~SQL
          SELECT service_provider as issuer,count(user_id) AS total
          FROM identities
          GROUP BY issuer ORDER BY issuer
        SQL
        ActiveRecord::Base.connection.execute(sql)
      end
    end
  end
end
