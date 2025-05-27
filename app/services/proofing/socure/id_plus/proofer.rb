# frozen_string_literal: true

module Proofing
  module Socure
    module IdPlus
      class Proofer
        attr_reader :config

        VENDOR_NAME = 'socure_kyc'
        UNKNOWN_REASON_CODE = '[unknown]'

        VERIFIED_ATTRIBUTE_MAP = {
          address: %i[streetAddress city state zip].freeze,
          first_name: :firstName,
          last_name: :surName,
          phone: :mobileNumber,
          ssn: :ssn,
          dob: :dob,
        }.freeze

        REQUIRED_ATTRIBUTES = %i[
          first_name
          last_name
          address
          dob
          ssn
        ].to_set.freeze

        # @param [Proofing::Socure::IdPlus::Config] config
        def initialize(config)
          @config = config
        end

        # @param [Hash] applicant
        # @return [Proofing::Resolution::Result]
        def proof(applicant)
          input = Input.new(applicant.slice(*Input.members))

          request = Request.new(config:, input:)

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

        # @param [Proofing::Socure::IdPlus::Response] response
        # @return [Proofing::Resolution::Result]
        def build_result_from_response(response)
          Proofing::Resolution::Result.new(
            success: all_required_attributes_verified?(response),
            errors: reason_codes_as_errors(response),
            exception: nil,
            vendor_name: VENDOR_NAME,
            verified_attributes: verified_attributes(response),
            transaction_id: response.reference_id,
            customer_user_id: response.customer_user_id,
          )
        end

        # @param [Proofing::Socure::IdPlus::Response] response
        # @return [Hash]
        def reason_codes_as_errors(response)
          known_codes = SocureReasonCode.where(
            code: response.kyc_reason_codes,
          ).pluck(:code, :description).to_h
          response.kyc_reason_codes.index_with { |code| known_codes[code] || UNKNOWN_REASON_CODE }
        end

        # @param [Proofing::Socure::IdPlus::Response] response
        def verified_attributes(response)
          VERIFIED_ATTRIBUTE_MAP.each_with_object([]) do |(attr_name, field_names), result|
            if Array(field_names).all? { |f| response.kyc_field_validations[f] }
              result << attr_name
            end
          end.to_set
        end
      end
    end
  end
end
