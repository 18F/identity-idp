module Db
  module Identity
    class UniqueIdentitiesPerIalCount
      def self.call(ial)
        sql = <<~SQL
          SELECT COUNT(*) FROM (SELECT DISTINCT user_id FROM identities WHERE ial=#{ial}) TBL
        SQL
        ActiveRecord::Base.connection.execute(sql)[0]['count'].to_i
      end
    end
  end
end
