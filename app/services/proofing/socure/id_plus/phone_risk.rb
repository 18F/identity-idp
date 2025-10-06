# frozen_string_literal: true

module Proofing
  module Socure
    module IdPlus
      class PhoneRisk < Proofer
        attr_reader :config

        VENDOR_NAME = 'socure_phonerisk'

        REQUIRED_ATTRIBUTES = %i[
          phone
          first_name
          last_name
        ].to_set.freeze

        # @param [Hash] applicant
        # @return [Proofing::Resolution::Result]
        def proof(applicant)
          input = Input.new(applicant.slice(*Input.members))

          request = Requests::PhoneRiskRequest.new(config:, input:)

          response = request.send_request

          build_result_from_response(response)
        rescue Proofing::TimeoutError, Request::Error => err
          NewRelic::Agent.notice_error(err)
          build_result_from_error(err)
        end

        private

        def all_required_attributes_verified?(response)
          (REQUIRED_ATTRIBUTES - response.verified_attributes).empty?
        end

        def build_result_from_error(err)
          AddressResult.new(
            success: false,
            exception: err,
            vendor_name: VENDOR_NAME,
            reference: err.respond_to?(:reference_id) ? err.reference_id : nil,
          )
        end

        def build_result_from_response(response)
          AddressResult.new(
            success: success?(response),
            exception: nil,
            vendor_name: VENDOR_NAME,
            reference: response.reference_id,
            result: response.to_h,
          )
        end

        def success?(response)
          response.successful? &&
            all_required_attributes_verified?(response)
        end
      end
    end
  end
end
