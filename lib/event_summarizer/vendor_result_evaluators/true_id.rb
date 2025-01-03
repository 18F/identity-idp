# frozen_string_literal: true

module EventSummarizer
  module VendorResultEvaluators
    module TrueId
      # @param result {Hash} The array of processed_alerts.failed logged to Cloudwatch
      # @return [Hash] A Hash with a type and description keys.
      def self.evaluate_result(result)
        alerts = []
        result['failed'].each do |alert|
          if alert['result'] == 'Failed'
            alerts << {
              type: :"trueid_#{alert['name'].parameterize(separator: '_')}",
              description: alert['disposition'],
            }
          end
        end

        if alerts.present?
          alerts.uniq! { |a| a[:description] }
          return {
            type: :trueid_failures,
            description: "TrueID request failed. #{alerts.map { |a| a[:description] }.join(' ')}",
          }
        end
      end
    end
  end
end
