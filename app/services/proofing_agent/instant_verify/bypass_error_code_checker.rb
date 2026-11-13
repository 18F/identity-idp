# frozen_string_literal: true

module ProofingAgent
  module InstantVerify
    class BypassErrorCodeChecker
      attr_reader :errors

      INSTANT_VERIFY_PRODUCT_TYPES = %w[InstantVerify Verification Verify].freeze

      def initialize(errors:)
        @errors = errors
      end

      def call
        failed_attributes = failed_attributes_from_products

        failed_attributes.present? && (failed_attributes - bypass_errors).empty?
      end

      private

      def bypass_errors
        # reference CheckToAttributeMapper for mapping of failed checks to attributes
        IdentityConfig.store.ssa_instant_verify_bypass_error_codes.map(&:to_sym)
      end

      def failed_attributes_from_products
        instant_verify_products.flat_map do |product|
          Proofing::LexisNexis::InstantVerify::CheckToAttributeMapper
            .new(product)
            .map_failed_checks_to_attributes
        end.uniq
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
