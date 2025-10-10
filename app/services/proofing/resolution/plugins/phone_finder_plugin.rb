# frozen_string_literal: true

module Proofing
  module Resolution
    module Plugins
      class PhoneFinderPlugin
        def call(
          applicant_pii:,
          current_sp:,
          state_id_address_resolution_result:,
          residential_address_resolution_result:,
          state_id_result:,
          ipp_enrollment_in_progress:,
          timer:
        )
          if ipp_enrollment_in_progress
            return ignore_phone_for_in_person_result
          end

          if !state_id_address_resolution_result.success? ||
             !residential_address_resolution_result.success? ||
             !state_id_result.success?
            return resolution_cannot_pass_result
          end

          if applicant_pii[:phone].blank?
            return no_phone_available_result
          end

          phone_finder_applicant = applicant_pii.slice(
            :uuid, :uuid_prefix, :first_name, :last_name, :ssn, :dob, :phone
          )

          timer.time('phone') do
            proofer.proof(phone_finder_applicant)
          end.tap do |result|
            if result.exception.blank?
              Db::SpCost::AddSpCost.call(
                current_sp,
                :lexis_nexis_address,
                transaction_id: result.transaction_id,
              )
            end
          end
        end

        def proofer
          @proofer ||=
            if IdentityConfig.store.proofer_mock_fallback
              Proofing::Mock::AddressMockClient.new
            else
              Proofing::LexisNexis::PhoneFinder::Proofer.new(
                phone_finder_workflow: IdentityConfig.store.lexisnexis_phone_finder_workflow,
                account_id: IdentityConfig.store.lexisnexis_account_id,
                base_url: IdentityConfig.store.lexisnexis_base_url,
                username: IdentityConfig.store.lexisnexis_username,
                password: IdentityConfig.store.lexisnexis_password,
                hmac_key_id: IdentityConfig.store.lexisnexis_hmac_key_id,
                hmac_secret_key: IdentityConfig.store.lexisnexis_hmac_secret_key,
                request_mode: IdentityConfig.store.lexisnexis_request_mode,
              )
            end
        end

        private

        def resolution_cannot_pass_result
          Proofing::Resolution::Result.new(
            success: false, vendor_name: 'ResolutionCannotPass',
          )
        end

        def ignore_phone_for_in_person_result
          Proofing::Resolution::Result.new(
            success: false, vendor_name: 'PhoneIgnoredForInPersonProofing',
          )
        end

        def no_phone_available_result
          Proofing::Resolution::Result.new(
            success: false, vendor_name: 'NoPhoneNumberAvailable',
          )
        end
      end
    end
  end
end
