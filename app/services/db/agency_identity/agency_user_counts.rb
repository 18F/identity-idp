module Db
  module AgencyIdentity
    class AgencyUserCounts
      def self.call
        sql = <<~SQL
          SELECT name AS agency, count(user_id) AS total
          FROM agency_identities, agencies
          WHERE agencies.id = agency_identities.agency_id
          GROUP BY agency ORDER BY agency
        SQL
        ActiveRecord::Base.connection.execute(sql)
      end
    end
  end
end
