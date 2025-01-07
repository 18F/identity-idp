# frozen_string_literal: true

module Proofing
  module Resolution
    module Plugins
      class AamvaPlugin
        SECONDARY_ID_ADDRESS_MAP = {
          identity_doc_address1: :address1,
          identity_doc_address2: :address2,
          identity_doc_city: :city,
          identity_doc_address_state: :state,
          identity_doc_zipcode: :zipcode,
        }.freeze

        def call(
          applicant_pii:,
          current_sp:,
          state_id_address_resolution_result:,
          ipp_enrollment_in_progress:,
          timer:
        )
          should_proof = should_proof_state_id?(
            applicant_pii:,
            state_id_address_resolution_result:,
            ipp_enrollment_in_progress:,
          )

          if !should_proof
            return out_of_aamva_jurisdiction_result
          end

          applicant_pii_with_state_id_address =
            if ipp_enrollment_in_progress
              with_state_id_address(applicant_pii)
            else
              applicant_pii
            end

          timer.time('state_id') do
            proofer.proof(applicant_pii_with_state_id_address)
          end.tap do |result|
            if result.exception.blank?
              Db::SpCost::AddSpCost.call(
                current_sp,
                :aamva,
                transaction_id: result.transaction_id,
              )
            end
          end
        end

        def aamva_supports_state_id_jurisdiction?(applicant_pii)
          state_id_jurisdiction = applicant_pii[:state_id_jurisdiction]
          IdentityConfig.store.aamva_supported_jurisdictions.include?(state_id_jurisdiction)
        end

        def out_of_aamva_jurisdiction_result
          Proofing::StateIdResult.new(
            errors: {},
            exception: nil,
            success: true,
            vendor_name: Idp::Constants::Vendors::AAMVA_UNSUPPORTED_JURISDICTION,
          )
        end

        def proofer
          @proofer ||=
            if IdentityConfig.store.proofer_mock_fallback
              Proofing::Mock::StateIdMockClient.new
            else
              Proofing::Aamva::Proofer.new(
                auth_request_timeout: IdentityConfig.store.aamva_auth_request_timeout,
                auth_url: IdentityConfig.store.aamva_auth_url,
                cert_enabled: IdentityConfig.store.aamva_cert_enabled,
                private_key: IdentityConfig.store.aamva_private_key,
                public_key: IdentityConfig.store.aamva_public_key,
                verification_request_timeout:
                  IdentityConfig.store.aamva_verification_request_timeout,
                verification_url: IdentityConfig.store.aamva_verification_url,
              )
            end
        end

        def same_address_as_id?(applicant_pii)
          applicant_pii[:same_address_as_id].to_s == 'true'
        end

        def should_proof_state_id?(
          applicant_pii:,
          state_id_address_resolution_result:,
          ipp_enrollment_in_progress:
        )
          return false unless aamva_supports_state_id_jurisdiction?(applicant_pii)
          # If the user is in in-person-proofing and they have changed their address then
          # they are not eligible for get-to-yes
          if !ipp_enrollment_in_progress || same_address_as_id?(applicant_pii)
            user_can_pass_after_state_id_check?(state_id_address_resolution_result:)
          else
            state_id_address_resolution_result.success?
          end
        end

        def user_can_pass_after_state_id_check?(
          state_id_address_resolution_result:
        )
          return true if state_id_address_resolution_result.success?

          # For failed IV results, this method validates that the user is eligible to pass if the
          # failed attributes are covered by the same attributes in a successful AAMVA response
          # aka the Get-to-Yes w/ AAMVA feature.
          if !state_id_address_resolution_result
              .failed_result_can_pass_with_additional_verification?
            return false
          end

          attributes_aamva_can_pass = [:address, :dob, :state_id_number]
          attributes_requiring_additional_verification =
            state_id_address_resolution_result.attributes_requiring_additional_verification
          results_that_cannot_pass_aamva =
            attributes_requiring_additional_verification - attributes_aamva_can_pass

          results_that_cannot_pass_aamva.blank?
        end

        # Make a copy of pii with the user's state ID address overwriting the address keys
        # Need to first remove the address keys to avoid key/value collision
        def with_state_id_address(pii)
          pii.except(*SECONDARY_ID_ADDRESS_MAP.values)
            .transform_keys(SECONDARY_ID_ADDRESS_MAP)
        end
      end
    end
  end
end
