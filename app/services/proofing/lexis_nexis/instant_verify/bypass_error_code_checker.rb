# frozen_string_literal: true

module Proofing
  module LexisNexis
    module InstantVerify
      # bypass_error_codes is the raw configuration: a hash mapping an Instant Verify check name
      # to the failure reason codes that may be bypassed for that check, e.g.
      #   { 'SsnFullNameMatch' => ['ssn_fullname_not_match_fail'] }
      class BypassErrorCodeChecker
        attr_reader :errors, :bypass_error_codes

        INSTANT_VERIFY_PRODUCT_TYPES = %w[InstantVerify Verification Verify].freeze

        def initialize(errors:, bypass_error_codes:)
          @errors = errors
          @bypass_error_codes = normalize_bypass_error_codes(bypass_error_codes)
        end

        def call
          failed_items = failed_items_from_products

          failed_items.present? && failed_items.all? { |item| bypassable?(item) }
        end

        private

        def normalize_bypass_error_codes(configured)
          return {} unless configured.is_a?(Hash)

          configured.to_h do |check_name, codes|
            [check_name.to_s, Array(codes).map(&:to_s)]
          end
        end

        def bypassable?(item)
          reason = item['ItemReason']
          code = reason['Code'] if reason.is_a?(Hash)
          return false if code.blank?

          Array(bypass_error_codes[item['ItemName']]).include?(code)
        end

        def failed_items_from_products
          instant_verify_products
            .flat_map { |product| Array(product['Items']) }
            .select { |item| item.is_a?(Hash) && item['ItemStatus'] != 'pass' }
        end

        def instant_verify_products
          return [] unless errors.respond_to?(:to_h)

          errors.to_h.deep_stringify_keys.values.flatten.select do |value|
            value.is_a?(Hash) &&
              INSTANT_VERIFY_PRODUCT_TYPES.include?(value['ProductType']) &&
              value['Items'].present?
          end
        end
      end
    end
  end
end
