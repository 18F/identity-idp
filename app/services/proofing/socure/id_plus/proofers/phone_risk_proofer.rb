# frozen_string_literal: true

module Proofing
  module Socure
    module IdPlus
      module Proofers
        class PhoneRiskProofer < Proofing::Socure::IdPlus::Proofer
          attr_reader :config

          VENDOR_NAME = 'socure_phonerisk'

          # @param [Hash] applicant
          # @return [Proofing::Resolution::Result]
          def proof(applicant)
            input = Input.new(applicant.slice(*Input.members))

            response = request.send_request

            build_result_from_response(response)
          rescue Proofing::TimeoutError, Request::Error => err
            NewRelic::Agent.notice_error(err)
            build_result_from_error(err)
          end

          private

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
            response.successful?
          end

          def request(input)
            @request ||= Requests::PhoneRiskRequest.new(config:, input:)
          end
        end
      end
    end
  end
end
