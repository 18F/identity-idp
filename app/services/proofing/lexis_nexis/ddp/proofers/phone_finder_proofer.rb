# frozen_string_literal: true

module Proofing
  module LexisNexis
    module Ddp
      module Proofers
        class PhoneFinderProofer < Proofing::LexisNexis::Ddp::Proofer
          private

          def build_result_from_response(verification_response)
            parsed_response =
              Proofing::LexisNexis::Ddp::ParsedResponse.new(raw_response(verification_response))

            AddressResult.new(
              success: parsed_response.verification_status == 'passed',
              errors: parse_verification_errors(parsed_response),
              exception: nil,
              vendor_name: 'lexisnexis:phone_finder_ddp',
              transaction_id: parsed_response.conversation_id,
            )
          end

          def verification_request(applicant)
            Proofing::LexisNexis::Ddp::Requests::PhoneFinderRequest.new(config:, applicant:)
          end

          def parse_verification_errors(parsed_response)
            errors = Hash.new { |h, k| h[k] = [] }
            parsed_response.verification_errors.each do |key, value|
              errors[key] << value
            end
            errors
          end

          def raw_response(verification_response)
            verification_response.response_body.dig(
              'integration_hub_results',
              "#{IdentityConfig.store.lexisnexis_threatmetrix_org_id}:#{config.ddp_policy}",
              'Execute Phone Finder', 'tps_vendor_raw_response'
            )
          end
        end
      end
    end
  end
end
