module Db
  module Identity
    class TotalIdentitiesPerIalCount
      def self.call(ial, date)
        params = {
          ial: ActiveRecord::Base.connection.quote(ial),
          date: ActiveRecord::Base.connection.quote(date),
        }
        sql = format(<<~SQL, params)
          SELECT COUNT(*) FROM identities WHERE ial=%{ial} AND created_at < %{date}
        SQL
        ActiveRecord::Base.connection.execute(sql)[0]['count'].to_i
      end
    end
  end
end
