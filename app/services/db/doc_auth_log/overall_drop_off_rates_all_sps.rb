module Db
  module DocAuthLog
    class OverallDropOffRatesAllSps
      include DropOffRatesHelper

      def call(start, finish)
        drop_off_rates_all_sps(start, finish)
      end

      private

      def verified_user_counts_query
        <<~SQL
           select count(*)
           from profiles
           where verified_at is not null and active=true and 
             user_id in (select user_id from doc_auth_logs where '#{start}' <= welcome_view_at and welcome_view_at < '#{finish}' and (front_image_submit_count>0 or back_image_submit_count>0 or mobile_front_image_submit_count>0 or  mobile_back_image_submit_count>0 or  capture_mobile_back_image_submit_count>0))
        SQL
      end

      def drop_offs_query
        <<~SQL
          select count(welcome_view_at) as welcome, count(upload_view_at) as upload_option,
          count(COALESCE(front_image_view_at,mobile_front_image_view_at)) as front_image,
          count(COALESCE(back_image_view_at,mobile_back_image_view_at,capture_mobile_back_image_view_at)) as back_image,
          count(ssn_view_at) as ssn,
          count(verify_view_at) as verify_info,
          count(doc_success_view_at) as doc_success,
          count(verify_phone_view_at) as phone,
          count(encrypt_view_at) as encrypt,
          count(verified_view_at) as personal_key
          from doc_auth_logs where '#{start}' <= created_at and created_at < '#{finish}' and (front_image_submit_count>0 or back_image_submit_count>0 or mobile_front_image_submit_count>0 or  mobile_back_image_submit_count>0 or  capture_mobile_back_image_submit_count>0)
        SQL
      end
    end
  end
end
