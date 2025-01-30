# frozen_string_literal: true

module Proofing
  module Aamva
    class Proofer
      Config = RedactedStruct.new(
        :auth_request_timeout,
        :auth_url,
        :cert_enabled,
        :private_key,
        :public_key,
        :verification_request_timeout,
        :verification_url,
        keyword_init: true,
        allowed_members: [
          :auth_request_timeout,
          :auth_url,
          :cert_enabled,
          :verification_request_timeout,
          :verification_url,
        ],
      ).freeze

      REQUIRED_VERIFICATION_ATTRIBUTES = %i[
        state_id_number
        dob
        last_name
        first_name
      ].freeze

      REQUIRED_IF_PRESENT_ATTRIBUTES = [:state_id_expiration].freeze

      ADDRESS_ATTRIBUTES = [
        :address1,
        :address2,
        :city,
        :state,
        :zipcode,
      ].to_set.freeze

      OPTIONAL_ADDRESS_ATTRIBUTES = [:address2].freeze

      REQUIRED_ADDRESS_ATTRIBUTES = (ADDRESS_ATTRIBUTES - OPTIONAL_ADDRESS_ATTRIBUTES).freeze

      attr_reader :config

      # Instance methods
      def initialize(config)
        @config = Config.new(config)
        @client = Aamva::VerificationClient.new(config)
      end

      # @param applicant [Hash]
      def proof(applicant)
        aamva_applicant = Aamva::Applicant.from_proofer_applicant(applicant)
        request = build_verification_request(aamva_applicant)
        response = request&.send

        build_result(request, response, applicant[:state_id_jurisdiction])
      rescue => exception
        Proofing::StateIdResult.new(
          success: false,
          errors: {},
          exception: exception,
          vendor_name: 'aamva:state_id',
          transaction_id: nil,
          verified_attributes: [],
          requested_attributes: requested_attributes(request),
          jurisdiction_in_maintenance_window: jurisdiction_in_maintenance_window?(
            applicant[:state_id_jurisdiction],
          ),
        )
      end

      private

      def build_verification_request(applicant)
        Aamva::VerificationClient.new(config)
          .build_verification_request(applicant:)
      end

      def build_result(verification_request, verification_response, jurisdiction)
        Proofing::StateIdResult.new(
          success: successful?(verification_response),
          errors: parse_verification_errors(verification_response),
          exception: nil,
          vendor_name: 'aamva:state_id',
          transaction_id: verification_response.transaction_locator_id,
          requested_attributes: requested_attributes(verification_request),
          verified_attributes: verified_attributes(verification_response),
          jurisdiction_in_maintenance_window: jurisdiction_in_maintenance_window?(jurisdiction),
        )
      end

      def parse_verification_errors(verification_response)
        errors = Hash.new { |h, k| h[k] = [] }

        return errors if successful?(verification_response)

        verification_response.verification_results.each do |attribute, v_result|
          attribute_key = attribute.to_sym
          next if v_result == true
          errors[attribute_key] << 'UNVERIFIED' if v_result == false
          errors[attribute_key] << 'MISSING' if v_result.nil?
        end
        errors
      end

      # @param verification_request [Proofing::Aamva::Request::VerificationRequest]
      def requested_attributes(verification_request)
        return if verification_request.nil?
        present_attributes = verification_request
          .requested_attributes
          .compact
          .filter { |_k, v| v == 1 }
          .keys
          .to_set
        blank_attributes = verification_request
          .requested_attributes
          .filter { |_k, v| v == 0 }
        normalized = normalize_address_attributes(present_attributes).index_with(1)
        normalized.merge(blank_attributes)
      end

      def verified_attributes(verification_response)
        attributes = verification_response
          .verification_results.filter { |_, verified| verified }
          .keys
          .to_set

        normalize_address_attributes(attributes)
      end

      def normalize_address_attributes(attribute_set)
        all_present = REQUIRED_ADDRESS_ATTRIBUTES & attribute_set == REQUIRED_ADDRESS_ATTRIBUTES

        (attribute_set - ADDRESS_ATTRIBUTES).tap do |result|
          result.add(:address) if all_present
        end
      end

      def successful?(verification_response)
        REQUIRED_VERIFICATION_ATTRIBUTES.each do |verification_attribute|
          return false unless verification_response.verification_results[verification_attribute]
        end

        REQUIRED_IF_PRESENT_ATTRIBUTES.each do |verification_attribute|
          value = verification_response.verification_results[verification_attribute]
          return false unless value.nil? || value == true
        end

        true
      end

      def jurisdiction_in_maintenance_window?(state)
        Idv::AamvaStateMaintenanceWindow.in_maintenance_window?(state)
      end
    end
  end
end
