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
            errors: parse_verification_errors(response),
            exception: nil,
            vendor_name: 'socure:phone_risk',
            transaction_id: verification_response.conversation_id,
            customer_user_id: response.customer_user_id,
            reason_codes: reason_codes_as_errors(response)
          )
        end

        def parse_verification_errors(verification_response)
          errors = Hash.new { |h, k| h[k] = [] }
          verification_response.verification_errors.each do |key, value|
            errors[key] << value
          end
          errors
        end

        # @param [Proofing::Socure::IdPlus::Response] response
        # @return [Hash]
        def reason_codes_as_errors(response)
          known_codes = SocureReasonCode.where(
            code: response.phone_risk_reason_codes,
          ).pluck(:code, :description).to_h
          response.phone_risk_reason_codes.index_with { |code| known_codes[code] || UNKNOWN_REASON_CODE }
        end

        # @param [Proofing::Socure::IdPlus::Response] response
        def verified_attributes(response)
          VERIFIED_ATTRIBUTE_MAP.each_with_object([]) do |(attr_name, field_names), result|
            if Array(field_names).all? { |f| response.phone_risk_field_validations[f] }
              result << attr_name
            end
          end.to_set
        end

        def successful?(response)
          # all_required_attributes_verified?(response)
          true
        end
      end
    end
  end
end
