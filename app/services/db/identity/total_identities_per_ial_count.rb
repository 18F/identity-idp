module Db
  module Identity
    class TotalIdentitiesPerIalCount
      def self.call(ial)
        sql = <<~SQL
          SELECT COUNT(*) FROM identities WHERE ial=#{ial}
        SQL
        ActiveRecord::Base.connection.execute(sql)[0]['count'].to_i
      end
    end
  end
end
