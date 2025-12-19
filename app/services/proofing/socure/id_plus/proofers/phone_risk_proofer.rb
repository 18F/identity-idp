# frozen_string_literal: true

module Proofing
  module Socure
    module IdPlus
      module Proofers
        class PhoneRiskProofer < Proofing::Socure::IdPlus::Proofer
          attr_reader :config

          VENDOR_NAME = 'socure_phonerisk'

          private

          def build_result_from_error(err)
            reference = err.respond_to?(:reference_id) ? err.reference_id : nil
            AddressResult.new(
              success: false,
              exception: err,
              vendor_name: VENDOR_NAME,
              reference:,
              transaction_id: reference,
            )
          end

          def build_result_from_response(response)
            reference = response.reference_id
            AddressResult.new(
              success: success?(response),
              errors: parse_errors(response),
              exception: nil,
              vendor_name: VENDOR_NAME,
              reference:,
              transaction_id: reference,
              result: response.to_h,
            )
          end

          def success?(response)
            response.successful?
          end

          def request(input)
            @request ||= Requests::PhoneRiskRequest.new(config:, input:)
          end

          def parse_errors(response)
            return {} if success?(response)

            response_hash = response.to_h
            phonerisk_codes = response_hash.dig(:phonerisk, :reason_codes) || {}
            name_phone_codes = response_hash.dig(:name_phone_correlation, :reason_codes) || {}

            combined_reason_codes = phonerisk_codes.merge(name_phone_codes)

            {
              socure: {
                reason_codes: combined_reason_codes,
              },
            }
          end
        end
      end
    end
  end
end
