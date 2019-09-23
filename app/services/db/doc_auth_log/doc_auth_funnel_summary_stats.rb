module Db
  module DocAuthLog
    class DocAuthFunnelSummaryStats
      SKIP_FIELDS = %w[id user_id created_at updated_at].freeze

      def call
        total_count = ::DocAuthLog.count
        return {} if total_count.zero?
        convert_percentages(total_count)
        results['total_verified_users_count'] = ::DocAuthLog.verified_users_count
        results['total_verify_attempted_users_count'] = total_count
        results
      end

      private

      def convert_percentages(total_count)
        results.each do |key, value|
          multiplier = key.end_with?('_percent') ? 100.0 : 1.0
          results[key] = (value * multiplier / total_count).round(2)
        end
      end

      def results
        @results ||= execute_funnel_sql
      end

      def execute_funnel_sql
        sep = ''
        ::DocAuthLog.new.attributes.keys.each do |attribute|
          next unless append_sql(sql_a, attribute, sep)
          sep = ','
        end
        sql_a << ' FROM doc_auth_logs'
        ActiveRecord::Base.connection.execute(sql_a.join)[0]
      end

      def append_sql(sql_a, attribute, sep)
        return if SKIP_FIELDS.index(attribute)
        sql_a << aggregate_sql(attribute, sep)
        true
      end

      def sql_a
        @sql_a ||= ['SELECT ']
      end

      def aggregate_sql(attribute, sep)
        if attribute.end_with?('_at')
          "#{sep}count(#{attribute}) AS #{attribute[0..-3]}percent"
        else
          "#{sep}sum(#{attribute}) AS #{attribute}_average"
        end
      end
    end
  end
end
