module Db
  module ProofingCost
    class ProofingCostsSummary
      SKIP_FIELDS = %w[id user_id created_at updated_at].freeze

      def call
        total_count = ::ProofingCost.count
        return {} if total_count.zero?
        results.each do |key, value|
          results[key] = (value.to_f / total_count).round(2)
        end
        results['total_proofing_costs_users_count'] = total_count
        results
      end

      private

      def results
        @results ||= execute_summary_sql
      end

      def execute_summary_sql
        sep = ''
        ::ProofingCost.new.attributes.keys.each do |attribute|
          next unless append_sql(sql_a, attribute, sep)
          sep = ','
        end
        sql_a << ' FROM proofing_costs'
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
        "#{sep}sum(#{attribute}) AS #{attribute}_average"
      end
    end
  end
end
