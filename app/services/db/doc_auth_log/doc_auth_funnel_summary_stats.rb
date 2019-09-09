module Db
  module DocAuthLog
    class DocAuthFunnelSummaryStats
      SKIP_FIELDS = %w[id user_id].freeze

      def call
        total_count = ::DocAuthLog.count
        return {} if total_count.zero?
        hash = execute_funnel_sql
        hash.each do |key, value|
          multiplier = key.end_with?('_percent') ? 100.0 : 1.0
          hash[key] = (value * multiplier / total_count).round
        end
        hash['total_verified_users_count'] = ::DocAuthLog.verified_users_count
        hash['total_verify_attempted_users_count'] = total_count
        hash
      end

      private

      def execute_funnel_sql
        cmd = ['SELECT ']
        sep = ''
        ::DocAuthLog.new.attributes.keys.each do |attribute|
          next if SKIP_FIELDS.index(attribute)
          cmd << aggregate_sql(attribute, sep)
          sep = ','
        end
        cmd << ' FROM doc_auth_logs'
        ActiveRecord::Base.connection.execute(cmd.join)[0]
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
