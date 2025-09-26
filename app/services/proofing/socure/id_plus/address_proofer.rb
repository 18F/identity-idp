# frozen_string_literal: true

module Proofing
  module Socure
    module IdPlus
      class AddressProofer
        attr_reader :config

        VENDOR_NAME = 'socure_phonerisk'
        UNKNOWN_REASON_CODE = '[unknown]'

        VERIFIED_ATTRIBUTE_MAP = {
          phone: :mobileNumber,
          first_name: :firstName,
          last_name: :surName,
        }.freeze

        REQUIRED_ATTRIBUTES = %i[
          phone
          first_name
          last_name
        ].to_set.freeze

        # @param [Proofing::Socure::IdPlus::Config] config
        def initialize(config)
          @config = config
        end

        # @param [Hash] applicant
        # @return [Proofing::Resolution::Result]
        def proof(applicant)
          input = Input.new(applicant.slice(*Input.members))

          request = PhoneRiskRequest.new(config:, input:)

          response = request.send_request

          build_result_from_response(response)
        rescue Proofing::TimeoutError, Request::Error => err
          NewRelic::Agent.notice_error(err)
          build_result_from_error(err)
        end

        private

        # @param [Proofing::Socure::IdPlus::Response] response
        def all_required_attributes_verified?(response)
          (REQUIRED_ATTRIBUTES - verified_attributes(response)).empty?
        end

        def build_result_from_error(err)
          Proofing::Resolution::Result.new(
            success: false,
            errors: {},
            exception: err,
            vendor_name: VENDOR_NAME,
            transaction_id: err.respond_to?(:reference_id) ? err.reference_id : nil,
          )
        end

        def build_result_from_response(response)
          AddressResult.new(
            success: successful?(response),
            errors: nil,
            exception: nil,
            vendor_name: 'socure:phonerisk',
            reference: response.reference_id,
            transaction_id: nil,
            customer_user_id: response.customer_user_id,
            reason_codes: reason_codes_as_errors(response),
          )
        end

        # @param [Proofing::Socure::IdPlus::Response] response
        # @return [Hash]
        def reason_codes_as_errors(response)
          known_codes = SocureReasonCode.where(
            code: response.phonerisk_reason_codes,
          ).pluck(:code, :description).to_h
          response.phonerisk_reason_codes.index_with { |code| known_codes[code] || UNKNOWN_REASON_CODE }
        end

        # @param [Proofing::Socure::IdPlus::Response] response
        def verified_attributes(response)
          result = []
          result = %i[first_name last_name] if response.name_phone_correlation_score
          result << :phone if response.phonerisk_score
        end

        def successful?(response)
          name_correlation_successful?(response) && phonerisk_successful?(response) &&
            all_required_attributes_verified?(response)
        end

        def phonerisk_successful?(response)
          return false unless response.phonerisk_score

          response.phonerisk_score < IdentityConfig.store.idv_socure_phonerisk_score_threshold
        end

        def name_correlation_successful?(response)
          return false unless response.name_phone_correlation_score

          IdentityConfig.store.idv_socure_phonerisk_name_correlation_score_threshold < response.name_phone_correlation_score
        end
      end
    end
  end
end
