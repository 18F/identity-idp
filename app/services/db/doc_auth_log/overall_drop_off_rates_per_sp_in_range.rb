module Db
  module DocAuthLog
    class OverallDropOffRatesPerSpInRange
      include DropOffRatesHelper

      def call(title, issuer, start, finish)
        drop_off_rates(title: title, issuer: issuer, start: start, finish: finish)
      end

      private

      def verified_user_counts_query
        <<~SQL
           select count(*) from identities where issuer='#{issuer}' and '#{start}' <= created_at and created_at < '#{finish}'
        SQL
      end

      def drop_offs_query
        <<~SQL
          #{select_counts_from_doc_auth_logs}
          where issuer='#{issuer}' and '#{start}' <= welcome_view_at and welcome_view_at < '#{finish}' and (front_image_submit_count>0 or back_image_submit_count>0 or mobile_front_image_submit_count>0 or  mobile_back_image_submit_count>0 or  capture_mobile_back_image_submit_count>0)
        SQL
      end
    end
  end
end
