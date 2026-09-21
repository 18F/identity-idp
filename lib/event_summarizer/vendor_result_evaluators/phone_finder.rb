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

      # Items are read regardless of ProductStatus: LexisNexis marks the PhoneFinder product 'pass'
      # when the lookup ran, even while individual Items fail. The verdict is in PhoneFinder Checks.
      def self.itemized_errors(result)
        failed_items = []
        pf_instances = result.dig('errors', 'PhoneFinder')
        return [] unless pf_instances && !pf_instances.empty?

        pf_instances.each do |pf_instance|
          items = pf_instance['Items'] || []

          items.each do |item|
            failed_items << item if item['ItemStatus'] == 'fail'
          end
        end

        failed_items.filter_map { |item| failure_reason(item) }.uniq
      end

      def self.failure_reason(item)
        reason = item.dig('ItemReason', 'Description').to_s.strip

        reason unless reason.empty?
      end

      def self.general_error(result)
        checks = result.dig('errors', 'PhoneFinder Checks')
        return nil unless checks && !checks.empty?

        failed_status = checks.find { |status| status['ProductStatus'] == 'fail' }

        failed_status&.dig('ProductReason', 'Description')
      end

      # Itemized reasons first: the general error is the same text on every failure, and misleading
      # when the real reason is e.g. a deceased subject rather than a name mismatch.
      def self.failure_payload(result)
        fail_reasons = itemized_errors(result)
        fail_reasons = [general_error(result)].compact if fail_reasons.empty?

        detail =
          if fail_reasons.any?
            ": #{fail_reasons.join('; ')}"
          else
            '. Review logs for more information.'
          end

        {
          type: :phone_finder_error,
          description: "Phone Finder check failed#{detail}",
        }
      end
    end
  end
end
