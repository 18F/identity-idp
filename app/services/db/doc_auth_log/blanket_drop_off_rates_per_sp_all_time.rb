module Db
  module DocAuthLog
    class BlanketDropOffRatesPerSpAllTime
      include DropOffRatesHelper

      def call(title, issuer)
        drop_off_rates(title: title, issuer: issuer, start: oldest_ial2_date, finish: Date.tomorrow)
      end

      private

      def verified_user_counts_query
        <<~SQL
          select count(*) from identities
          where ial>=2 and service_provider = '#{@issuer}' and
          user_id in (select user_id from profiles)
        SQL
      end

      def drop_offs_query
        <<~SQL
          #{select_counts_from_doc_auth_logs} where issuer='#{@issuer}'
        SQL
      end
    end
  end
end
