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
          select count(*) from identities
          where service_provider='#{issuer}' and ial>=2
          and user_id in (select user_id from doc_auth_logs where #{start} <= welcome_view_at and welcome_view_at < #{finish} and #{images_or_piv_cac_submitted})
          and user_id in (select user_id from profiles)
        SQL
      end

      def drop_offs_query
        <<~SQL
          #{select_counts_from_doc_auth_logs}
          where issuer='#{issuer}' and #{start} <= welcome_view_at and welcome_view_at < #{finish}
          and ((#{images_or_piv_cac_submitted}) OR (#{piv_cac_submitted}))
        SQL
      end
    end
  end
end
