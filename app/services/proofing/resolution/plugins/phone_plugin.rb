# frozen_string_literal: true

module Proofing
  module Resolution
    module Plugins
      class PhonePlugin
        def call(
          applicant_pii:,
          current_sp:,
          state_id_address_resolution_result:,
          residential_address_resolution_result:,
          state_id_result:,
          ipp_enrollment_in_progress:,
          user_email:,
          timer:,
          best_effort_phone: nil

        )
          return {} unless IdentityConfig.store.idv_phone_precheck_enabled

          if !state_id_address_resolution_result.success? ||
             !residential_address_resolution_result.success? ||
             !state_id_result.success?
            return resolution_cannot_pass_result.to_h
          end

          if IdentityConfig.store.idv_phone_precheck_enabled
            applicant_pii[:phone] ||= best_effort_phone&.dig(:phone)
          end

          if applicant_pii[:phone].blank?
            return no_phone_available_result.to_h
          end

          phone_finder_applicant = applicant_pii.slice(
            :uuid, :uuid_prefix, :first_name, :last_name, :ssn, :dob, :phone
          )

          proofer = Proofing::AddressProofer.new(
            user_uuid: phone_finder_applicant[:uuid],
            user_email:,
          )
          timer.time('phone') do
            proofer.proof(applicant_pii: phone_finder_applicant, current_sp:)
          end
        end

        private

        def resolution_cannot_pass_result
          Proofing::AddressResult.new(
            success: false, vendor_name: 'ResolutionCannotPass', exception: nil,
          )
        end

        def ignore_phone_for_in_person_result
          Proofing::AddressResult.new(
            success: false, vendor_name: 'PhoneIgnoredForInPersonProofing', exception: nil,
          )
        end

        def no_phone_available_result
          Proofing::AddressResult.new(
            success: false, vendor_name: 'NoPhoneNumberAvailable', exception: nil,
          )
        end
      end
    end
  end
end
