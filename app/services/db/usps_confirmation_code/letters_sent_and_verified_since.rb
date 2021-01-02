module Db
  module UspsConfirmationCode
    class LettersSentAndVerifiedSince
      def self.call(start_date)
        params = {
            start: ActiveRecord::Base.connection.quote(start_date),
        }
        sql = format(<<~SQL, params)
          SELECT COUNT(*)
          FROM profiles
          WHERE active=true AND activated_at IS NOT NULL AND verified_at IS NOT NULL AND id IN
          (SELECT profile_id FROM usps_confirmation_codes WHERE %{start}<=created_at)
        SQL
        recs = ActiveRecord::Base.connection.execute(sql)
        recs[0]['count'].to_i
      end
    end
  end
end
