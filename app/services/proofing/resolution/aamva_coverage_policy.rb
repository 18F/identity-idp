# frozen_string_literal: true

module Proofing
  module Resolution
    class AamvaCoveragePolicy
      attr_reader :aamva_verified_attributes, :address_edited

      def self.from_applicant_pii(applicant_pii)
        new(
          aamva_verified_attributes: applicant_pii[:aamva_verified_attributes],
          address_edited: applicant_pii[:address_edited],
        )
      end

      def initialize(aamva_verified_attributes:, address_edited:)
        @aamva_verified_attributes = aamva_verified_attributes
        @address_edited = address_edited
      end

      def covers?(resolution_result:, proofing_vendor:)
        return false unless enabled_for_vendor?(proofing_vendor)
        return false unless resolution_result.failed_result_can_pass_with_additional_verification?

        unverified_attributes = resolution_result.attributes_requiring_additional_verification
        (unverified_attributes - usable_verified_attributes).empty?
      end

      def usable_verified_attributes
        attributes = normalized_verified_attributes
        attributes.delete(:address) if address_edited?
        attributes
      end

      private

      def normalized_verified_attributes
        return [] unless aamva_verified_attributes

        aamva_verified_attributes.map(&:to_sym)
      end

      def enabled_for_vendor?(proofing_vendor)
        IdentityConfig.store.idv_aamva_get_to_yes_enabled_vendors
          .include?(proofing_vendor.to_s)
      end

      def address_edited?
        address_edited == true
      end
    end
  end
end
