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
      end

      def proof(applicant)
        aamva_applicant = Aamva::Applicant.from_proofer_applicant(applicant)

        response = Aamva::VerificationClient.new(
          config,
        ).send_verification_request(
          applicant: aamva_applicant,
        )

        build_result_from_response(response, applicant[:state_id_jurisdiction])
      rescue => exception
        failed_result = Proofing::StateIdResult.new(
          success: false, errors: {}, exception: exception, vendor_name: 'aamva:state_id',
          transaction_id: nil, verified_attributes: [],
          jurisdiction_in_maintenance_window: jurisdiction_in_maintenance_window?(
            applicant[:state_id_jurisdiction],
          )
        )
        send_to_new_relic(failed_result)
        failed_result
      end

      private

      def build_result_from_response(verification_response, jurisdiction)
        Proofing::StateIdResult.new(
          success: successful?(verification_response),
          errors: parse_verification_errors(verification_response),
          exception: nil,
          vendor_name: 'aamva:state_id',
          transaction_id: verification_response.transaction_locator_id,
          requested_attributes: requested_attributes(verification_response).index_with(1),
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

      def requested_attributes(verification_response)
        attributes = verification_response
          .verification_results.filter { |_, verified| !verified.nil? }
          .keys
          .to_set

        normalize_address_attributes(attributes)
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

      def send_to_new_relic(result)
        if result.mva_timeout?
          return # noop
        end
        NewRelic::Agent.notice_error(result.exception)
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
