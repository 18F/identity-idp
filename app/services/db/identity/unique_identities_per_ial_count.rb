module Db
  module Identity
    class UniqueIdentitiesPerIalCount
      def self.call(ial, date)
        params = {
          ial: ActiveRecord::Base.connection.quote(ial),
          date: ActiveRecord::Base.connection.quote(date),
        }
        sql = format(<<~SQL, params)
          SELECT COUNT(*) FROM
          (SELECT DISTINCT user_id FROM identities WHERE ial=%{ial} AND created_at < %{date}) TBL
        SQL
        ActiveRecord::Base.connection.execute(sql)[0]['count'].to_i
      end
    end
  end
end
