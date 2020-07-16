module Db
  module DocAuthLog
    class BlanketDropOffRatesAllSpsAllTime
      include DropOffRatesHelper

      def call(title)
        drop_off_rates(title: title)
      end

      private

      def verified_user_counts_query
        <<~SQL
          #{select_count_from_profiles_where_verified_and_active}
        SQL
      end

      def drop_offs_query
        <<~SQL
          #{select_counts_from_doc_auth_logs}
        SQL
      end
    end
  end
end
