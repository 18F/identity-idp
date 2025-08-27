# frozen_string_literal: true

module EventSummarizer
  module VendorResultEvaluators
    module PhoneFinder
      def self.evaluate_result(result)
        exception_payload(result) || failure_payload(result)
      end

      def self.exception_payload(result)
        exception = result.dig('vendor', 'exception').to_s.strip

        return nil if exception.empty?

        {
          type: :phone_finder_exception,
          description: "Vendor exception: #{exception}",
        }
      end

      def self.failure_payload(result)
        failed_items = []
        pf_instances = result.dig('errors', 'PhoneFinder')
        pf_instances&.each do |pf_instance|
          next if pf_instance['ProductStatus'] != 'fail'

          items = pf_instance['Items']
          failed_items.concat(items.select { |item| item['ItemStatus'] == 'fail' })
        end

        fail_reasons = failed_items
          .map { |item| item.dig('ItemReason', 'Description').to_s.strip }
          .reject(&:empty?)
          .uniq

        if fail_reasons.any?
          {
            type: :phone_finder_error,
            description: "Phone Finder check failed: #{fail_reasons.uniq.join('; ')}",
          }
        else
          {
            type: :phone_finder_error,
            description: 'Phone Finder check failed. Review logs for more information.',
          }
        end
      end
    end
  end
end
