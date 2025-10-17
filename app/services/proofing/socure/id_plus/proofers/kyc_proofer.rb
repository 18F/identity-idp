# frozen_string_literal: true

module Proofing
  module Socure
    module IdPlus
      module Proofers
        class KycProofer < Proofing::Socure::IdPlus::Proofer
          attr_reader :config

          VENDOR_NAME = 'socure_kyc'

          private

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
              success: response.all_required_attributes_verified?,
              exception: nil,
              vendor_name: VENDOR_NAME,
              verified_attributes: response.verified_attributes,
              transaction_id: response.reference_id,
              customer_user_id: response.customer_user_id,
              reason_codes: SocureReasonCode.with_definitions(response.reason_codes),
            )
          end

          def request(input)
            @request ||= Requests::KycRequest.new(config:, input:)
          end
        end
      end
    end
  end
end
