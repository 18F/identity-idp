module Db
  module DocAuthLog
    class OverallDropOffRatesAllSpsAllTime
      include DropOffRatesHelper

      def call(title, start, finish)
        drop_off_rates(title: title, start: start, finish: finish)
      end

      private

      def verified_user_counts_query
        <<~SQL
          #{select_count_from_profiles_where_verified_and_active}
          and user_id in (select user_id from doc_auth_logs where '#{start}' <= welcome_view_at and welcome_view_at < '#{finish}' and (front_image_submit_count>0 or back_image_submit_count>0 or mobile_front_image_submit_count>0 or  mobile_back_image_submit_count>0 or  capture_mobile_back_image_submit_count>0))
        SQL
      end

      def drop_offs_query
        <<~SQL
          #{select_counts_from_doc_auth_logs}
          where '#{start}' <= welcome_view_at and welcome_view_at < '#{finish}' and #{at_least_one_image_submitted}
        SQL
      end
    end
  end
end
