module Idv
  module Resolution
    class InstantVerifyPlugin
      RESULTS_KEY = :instant_verify

      attr_reader :ab_test_discriminator, :timer

      def initialize(
        ab_test_discriminator: nil,
        timer: nil
      )
        @ab_test_discriminator = ab_test_discriminator
        @timer = timer || JobHelpers::Timer.new
      end

      def call(
        input:,
        result:,
        next_plugin:
      )
        addresses = {
          address_of_residence: input&.address_of_residence,
          state_id_address: input&.state_id&.address,
        }.compact

        # address_results contains InstantVerify results for individual
        # addresses. It is seeded with any InstantVerify results passed
        # into this plugin (for idempotency).
        address_results = {
            **(result[RESULTS_KEY] || {}),
        }

        any_failed = false

        addresses.each do |(key, address)|
          # We can re-use a prior result for the same key or if the
          # address represented by the key is the same as `address`
          result_for_address = address_results[key] ||
                               address_results.find do |(key, result)|
                                 addresses[key] == address
                               end&.last

          if can_reuse_result_for_address?(result_for_address)
            address_results[key] = result_for_address
            next
          end

          # We avoid making subsequent API requests if any prior ones failed
          next if any_failed

          applicant = format_applicant_for_instant_verify(input, address)
          result = proofer.proof(applicant)
          address_results[key] = result

          any_failed = !result.success
        end

        plugin_result = {}
        plugin_result[RESULTS_KEY] = address_results

        next_plugin.call(**plugin_result)
      end

      private

      def can_reuse_result_for_address?(result)
        return false if result.nil?

        # If a result resulted in an exception, don't reuse it
        return false if result.exception

        true
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

      def lexisnexis_instant_verify_workflow
        ab_test_variables = Idv::LexisNexisInstantVerify.new(ab_test_discriminator).
          workflow_ab_testing_variables
        ab_test_variables[:instant_verify_workflow]
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
