module Db
  module DocAuthLog
    class BlanketDropOffRatesAllSpsInRange
      include DropOffRatesHelper

      def call(title, start, finish)
        drop_off_rates(title: title, start: start, finish: finish)
      end

      private

      def verified_user_counts_query
        <<~SQL
          #{select_count_from_profiles_where_verified_and_active}
          and user_id in (select user_id from doc_auth_logs where #{start} <= welcome_view_at and welcome_view_at < #{finish})
        SQL
      end

      def drop_offs_query
        <<~SQL
          #{select_counts_from_doc_auth_logs} where #{start} <= welcome_view_at and welcome_view_at < #{finish}
        SQL
      end
    end
  end
end
