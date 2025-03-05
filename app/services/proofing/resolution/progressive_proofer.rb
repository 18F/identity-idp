# frozen_string_literal: true

module Proofing
  module Resolution
    # Uses a combination of LexisNexis InstantVerify and AAMVA checks to verify that
    # a user's identity can be resolved against authoritative sources. This includes logic for when:
    #   1. The user is or is not within an AAMVA-participating jurisdiction
    #   2. The user has only provided one address for their residential and identity document
    #      address or separate residential and identity document addresses
    class ProgressiveProofer
      class InvalidProofingVendorError; end

      attr_reader :aamva_plugin,
                  :threatmetrix_plugin

      PROOFING_VENDOR_SP_COST_TOKENS = {
        mock: :mock_resolution,
        instant_verify: :lexis_nexis_resolution,
        socure_kyc: :socure_resolution,
      }.freeze

      def initialize
        @aamva_plugin = Plugins::AamvaPlugin.new
        @threatmetrix_plugin = Plugins::ThreatMetrixPlugin.new
      end

      # @param [Hash] applicant_pii keys are symbols and values are strings, confidential user info
      # @param [Boolean] ipp_enrollment_in_progress flag that indicates if user will have
      #   both state id address and current residential address verified
      # @param [String] request_ip IP address for request
      # @param [String] threatmetrix_session_id identifies the threatmetrix session
      # @param [JobHelpers::Timer] timer indicates time elapsed to obtain results
      # @param [String] user_email email address for applicant
      # @param [String] user_uuid user uuid for applicant
      # @return [ResultAdjudicator] object which contains the logic to determine proofing's result
      def proof(
        applicant_pii:,
        request_ip:,
        threatmetrix_session_id:,
        timer:,
        user_email:,
        ipp_enrollment_in_progress:,
        current_sp:,
        user_uuid:
      )
        applicant_pii = applicant_pii.except(:best_effort_phone_number_for_socure)

        device_profiling_result = threatmetrix_plugin.call(
          applicant_pii:,
          current_sp:,
          threatmetrix_session_id:,
          request_ip:,
          timer:,
          user_email:,
          user_uuid:,
        )

        residential_address_resolution_result = residential_address_plugin.call(
          applicant_pii:,
          current_sp:,
          ipp_enrollment_in_progress:,
          timer:,
        )

        state_id_address_resolution_result = state_id_address_plugin.call(
          applicant_pii:,
          current_sp:,
          residential_address_resolution_result:,
          ipp_enrollment_in_progress:,
          timer:,
        )

        state_id_result = aamva_plugin.call(
          applicant_pii:,
          current_sp:,
          state_id_address_resolution_result:,
          ipp_enrollment_in_progress:,
          timer:,
        )

        ResultAdjudicator.new(
          device_profiling_result: device_profiling_result,
          ipp_enrollment_in_progress: ipp_enrollment_in_progress,
          resolution_result: state_id_address_resolution_result,
          should_proof_state_id: aamva_plugin.aamva_supports_state_id_jurisdiction?(applicant_pii),
          state_id_result: state_id_result,
          residential_resolution_result: residential_address_resolution_result,
          same_address_as_id: applicant_pii[:same_address_as_id],
          applicant_pii: applicant_pii,
        )
      end

      def proofing_vendor
        @proofing_vendor ||= begin
          default_vendor = IdentityConfig.store.idv_resolution_default_vendor
          alternate_vendor = IdentityConfig.store.idv_resolution_alternate_vendor
          alternate_vendor_percent = IdentityConfig.store.idv_resolution_alternate_vendor_percent

          if alternate_vendor == :none
            return default_vendor
          end

          if (rand * 100) <= alternate_vendor_percent
            alternate_vendor
          else
            default_vendor
          end
        end
      end

      def residential_address_plugin
        @residential_address_plugin ||= Plugins::ResidentialAddressPlugin.new(
          proofer: create_proofer,
          sp_cost_token:,
        )
      end

      def state_id_address_plugin
        @state_id_address_plugin ||= Plugins::StateIdAddressPlugin.new(
          proofer: create_proofer,
          sp_cost_token:,
        )
      end

      def create_proofer
        case proofing_vendor
        when :instant_verify then create_instant_verify_proofer
        when :mock then create_mock_proofer
        when :socure_kyc then create_socure_proofer
        else
          raise InvalidProofingVendorError, "#{proofing_vendor} is not a valid proofing vendor"
        end
      end

      def create_instant_verify_proofer
        Proofing::LexisNexis::InstantVerify::Proofer.new(
          instant_verify_workflow: IdentityConfig.store.lexisnexis_instant_verify_workflow,
          account_id: IdentityConfig.store.lexisnexis_account_id,
          base_url: IdentityConfig.store.lexisnexis_base_url,
          username: IdentityConfig.store.lexisnexis_username,
          password: IdentityConfig.store.lexisnexis_password,
          hmac_key_id: IdentityConfig.store.lexisnexis_hmac_key_id,
          hmac_secret_key: IdentityConfig.store.lexisnexis_hmac_secret_key,
          request_mode: IdentityConfig.store.lexisnexis_request_mode,
        )
      end

      def create_mock_proofer
        Proofing::Mock::ResolutionMockClient.new
      end

      def create_socure_proofer
        Proofing::Socure::IdPlus::Proofer.new(
          Proofing::Socure::IdPlus::Config.new(
            api_key: IdentityConfig.store.socure_idplus_api_key,
            base_url: IdentityConfig.store.socure_idplus_base_url,
            timeout: IdentityConfig.store.socure_idplus_timeout_in_seconds,
          ),
        )
      end

      def sp_cost_token
        PROOFING_VENDOR_SP_COST_TOKENS[proofing_vendor].tap do |token|
          if !token.present?
            raise InvalidProofingVendorError,
                  "No cost token present for proofing vendor #{proofing_vendor}"
          end
        end
      end
    end
  end
end
