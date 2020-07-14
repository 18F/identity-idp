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
          where issuer='#{issuer}' and '#{start}' <= created_at and created_at < '#{finish}'
        SQL
      end

      def drop_offs_query
        <<~SQL
          #{select_counts_from_doc_auth_logs}
          where issuer='#{issuer}' and '#{start}' <= welcome_view_at and welcome_view_at < '#{finish}'
          and #{at_least_one_image_submitted}
        SQL
      end
    end
  end
end
