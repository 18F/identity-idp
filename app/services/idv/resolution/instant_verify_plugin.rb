module Idv
  module Resolution
    class InstantVerifyPlugin
      attr_reader :timer

      def initialize(timer: nil)
        @timer = timer || JobHelpers::Timer.new
      end

      def call(
        input:,
        next_plugin:,
        **
      )

        if !input.state_id
          return next_plugin.call(
            instant_verify: {
              success: false,
              reason: :no_state_id,
            },
          )
        end

        addresses = addresses_to_proof(input)

        if addresses.empty?
          return next_plugin.call(
            instant_verify: {
              success: false,
              reason: :no_addresses,
            },
          )
        end

        address_results = addresses.each_with_object({}) do |(key, address), hash|
          applicant = format_applicant_for_instant_verify(input, address)
          hash[key] = proofer.proof(applicant)
        end

        success = address_results.all? do |(key, proofing_result)|
          proofing_result.success
        end

        next_plugin.call(
          instant_verify: {
            success:,
            **address_results,
          },
        )
      end

      private

      def addresses_to_proof(input)
        addresses = {
          state_id_address: input&.state_id&.address,
          address_of_residence: input&.address_of_residence,
        }.compact

        addresses.each_with_object({}) do |(key, address), hash|
          hash[key] = address unless hash.value?(address)
        end
      end

      def format_applicant_for_instant_verify(
        input,
        address
      )
        {
          **input.state_id.to_h.slice(:first_name, :last_name, :dob),
          **address.to_h,
          ssn: input.other.ssn,
        }
      end

      def proofer
        @proofer ||=
          if IdentityConfig.store.proofer_mock_fallback
            Proofing::Mock::ResolutionMockClient.new
          else
            Proofing::LexisNexis::InstantVerify::Proofer.new(
              instant_verify_workflow: lexisnexis_instant_verify_workflow,
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
    end
  end
end
