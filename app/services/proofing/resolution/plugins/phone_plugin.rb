# frozen_string_literal: true

module Proofing
  module Resolution
    module Plugins
      class PhonePlugin
        attr_reader :phone_number
        def call(
          applicant_pii:,
          current_sp:,
          state_id_address_resolution_result:,
          residential_address_resolution_result:,
          state_id_result:,
          user_email:,
          timer:,
          best_effort_phone: nil

        )
          @phone_number = nil
          return {} unless precheck_enabled

          if !state_id_address_resolution_result.success? ||
             !residential_address_resolution_result.success? ||
             !state_id_result.success?
            return resolution_cannot_pass_result
          end

          applicant_pii[:phone] ||= best_effort_phone&.dig(:phone)

          if applicant_pii[:phone].blank?
            return no_phone_available_result
          end

          @phone_number = applicant_pii[:phone]

          phone_applicant = applicant_pii.slice(
            :uuid, :uuid_prefix, :first_name, :last_name, :ssn, :dob, :phone
          )

          proofer = Proofing::AddressProofer.new(
            user_uuid: phone_applicant[:uuid],
            user_email:,
          )
          timer.time('phone') do
            proofer.proof(applicant_pii: phone_applicant, current_sp:)
          end
        end

        private

        def resolution_cannot_pass_result
          Proofing::AddressResult.new(
            success: false, vendor_name: 'ResolutionCannotPass', exception: nil,
          ).to_h
        end

        def no_phone_available_result
          Proofing::AddressResult.new(
            success: false, vendor_name: 'NoPhoneNumberAvailable', exception: nil,
          ).to_h
        end

        def precheck_enabled
          @precheck_enabled ||= (rand * 100) <= IdentityConfig.store.idv_phone_precheck_percent
        end
      end
    end
  end
end
