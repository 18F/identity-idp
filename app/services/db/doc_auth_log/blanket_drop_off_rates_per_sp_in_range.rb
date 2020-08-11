module Db
  module DocAuthLog
    class BlanketDropOffRatesPerSpInRange
      include DropOffRatesHelper

      def call(title, issuer, start, finish)
        drop_off_rates(title: title, issuer: issuer, start: start, finish: finish)
      end

      private

      def verified_user_counts_query
        <<~SQL
          select count(*) from identities
          where ial>=2 and service_provider = '#{@issuer}' and #{start} <= created_at and created_at < #{finish}
          and user_id in (select user_id from profiles)
        SQL
      end

      def drop_offs_query
        <<~SQL
          #{select_counts_from_doc_auth_logs} where #{start} <= welcome_view_at and welcome_view_at < #{finish} and issuer='#{@issuer}'
        SQL
      end
    end
  end
end
