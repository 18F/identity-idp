module Db
  module DocAuthLog
    class OverallDropOffRatesAllSpsAllTime
      include DropOffRatesHelper

      def call(title)
        drop_off_rates(title: title)
      end

      private

      def verified_user_counts_query
        <<~SQL
          #{select_count_from_profiles_where_verified_and_active}
          and user_id in (select user_id from doc_auth_logs where #{at_least_one_image_submitted})
        SQL
      end

      def drop_offs_query
        <<~SQL
          #{select_counts_from_doc_auth_logs}
          where #{at_least_one_image_submitted}
        SQL
      end
    end
  end
end
