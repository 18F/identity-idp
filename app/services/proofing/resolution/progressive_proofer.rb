# frozen_string_literal: true

module Proofing
  module Resolution
    class ProgressiveProofer
      class InvalidProofingVendorError; end

      attr_reader :user_uuid,
                  :user_email,
                  :threatmetrix_plugin,
                  :phone_plugin,
                  :proofing_vendor,
                  :is_proofing_agent

      PROOFING_VENDOR_SP_COST_TOKENS = {
        mock: :mock_resolution,
        instant_verify: :lexis_nexis_resolution,
        instant_verify_ddp: :lexis_nexis_resolution,
        socure_kyc: :socure_resolution,
      }.freeze

      def initialize(user_uuid:, proofing_vendor:, user_email:, analytics:,
                     is_proofing_agent: false)
        @user_uuid = user_uuid
        @user_email = user_email
        @threatmetrix_plugin = Plugins::ThreatMetrixPlugin.new
        @phone_plugin = Plugins::PhonePlugin.new
        @proofing_vendor = proofing_vendor
        @analytics = analytics
        @is_proofing_agent = is_proofing_agent
      end

      # @param [Hash] applicant_pii keys are symbols and values are strings, confidential user info
      # @param [Boolean] ipp_enrollment_in_progress flag that indicates if user will have
      #   both state id address and current residential address verified
      # @param [String] request_ip IP address for request
      # @param [String] threatmetrix_session_id identifies the threatmetrix session
      # @param [JobHelpers::Timer] timer indicates time elapsed to obtain results
      # @param [String] user_uuid user uuid for applicant
      # @param [String] workflow user is in idv or auth workflow
      # @param [String] hybrid_mobile_threatmetrix_session_id identifies the hybrid tmx session
      # @param [String, nil] hybrid_mobile_request_ip IP address for hybrid mobile request
      # @return [ResultAdjudicator] object which contains the logic to determine proofing's result
      def proof(
        applicant_pii:,
        request_ip:,
        threatmetrix_session_id:,
        timer:,
        ipp_enrollment_in_progress:,
        current_sp:,
        workflow:,
        hybrid_mobile_threatmetrix_session_id: nil,
        hybrid_mobile_request_ip: nil
      )
        best_effort_phone = applicant_pii[:best_effort_phone_number_for_socure]
        applicant_pii = applicant_pii.except(:best_effort_phone_number_for_socure)

        device_profiling_result = threatmetrix_plugin.call(
          applicant_pii:,
          current_sp:,
          threatmetrix_session_id:,
          request_ip:,
          timer:,
          user_email:,
          user_uuid:,
          workflow:,
          ddp_policy: IdentityConfig.store.lexisnexis_threatmetrix_policy,
        )

        user_went_through_hybrid_handoff = hybrid_mobile_request_ip.present?
        if FeatureManagement.proofing_device_hybrid_profiling_collecting_enabled? &&
           user_went_through_hybrid_handoff
          hybrid_mobile_device_profiling_result = threatmetrix_plugin.call(
            applicant_pii:,
            current_sp:,
            threatmetrix_session_id: hybrid_mobile_threatmetrix_session_id,
            request_ip: hybrid_mobile_request_ip,
            timer:,
            user_email:,
            user_uuid:,
            workflow: :"#{workflow}_hybrid_handoff",
            ddp_policy: IdentityConfig.store.lexisnexis_threatmetrix_hybrid_handoff_policy,
          )
        end

        resolution = proof_resolution_with_failover(
          applicant_pii:,
          current_sp:,
          ipp_enrollment_in_progress:,
          timer:,
        )

        phone_result = phone_plugin.call(
          applicant_pii:,
          current_sp:,
          residential_address_resolution_result: resolution[:residential_resolution_result],
          state_id_address_resolution_result: resolution[:resolution_result],
          best_effort_phone:,
          timer:,
          user_email:,
          is_proofing_agent:,
        )

        ResultAdjudicator.new(
          device_profiling_result:,
          hybrid_mobile_device_profiling_result:,
          ipp_enrollment_in_progress:,
          **resolution,
          phone_result:,
          ipp_current_address_matches_id: applicant_pii[:ipp_current_address_matches_id],
          applicant_pii:,
          precheck_phone_number: phone_plugin.phone_number,
        )
      end

      # Only returned resolution failures trigger failover. Provider exceptions keep propagating.
      def proof_resolution_with_failover(
        applicant_pii:,
        current_sp:,
        ipp_enrollment_in_progress:,
        timer:
      )
        failover_enabled = IdentityConfig.store.idv_resolution_failover_enabled
        vendors = failover_enabled ? resolution_vendors : [proofing_vendor]
        attempts = []
        resolution = nil
        arguments = { applicant_pii:, current_sp:, ipp_enrollment_in_progress: }
        vendors.each do |vendor|
          attempt_timer = failover_enabled ? JobHelpers::Timer.new : timer
          begin
            resolution = resolve_identity(vendor:, **arguments, timer: attempt_timer)
          ensure
            if failover_enabled
              attempt_timer.results.each do |stage, duration|
                timer.results["#{stage} #{vendor}"] = duration
              end
            end
          end
          break unless failover_enabled

          adjudicator = ResultAdjudicator.new(
            **resolution,
            applicant_pii:,
            ipp_enrollment_in_progress:,
            ipp_current_address_matches_id: applicant_pii[:ipp_current_address_matches_id],
            phone_result: {},
            precheck_phone_number: nil,
            device_profiling_result: nil,
          )
          attempts << adjudicator.resolution_attempt_summary
          break if adjudicator.resolution_success?
        end
        resolution.merge(failover_enabled ? { resolution_attempts: attempts } : {})
      end

      # The default bucket also receives any unallocated primary traffic. Bucket order breaks ties.
      def resolution_vendors
        test = is_proofing_agent ? AbTests::PROOFING_AGENT_PROOFING_VENDOR : AbTests::PROOFING_VENDOR
        shares = test.buckets.dup
        shares[test.default_bucket] = shares.fetch(test.default_bucket, 0) + 100 - shares.values.sum
        fallbacks = shares.each_with_index
          .select { |(vendor, share), _| share.positive? && vendor != :mock }
          .sort_by { |(_, share), index| [-share, index] }
          .map { |(vendor, _), _| vendor }
        [proofing_vendor, *fallbacks].uniq
      end

      # Resolves the full identity (name, DOB, SSN, address) with one vendor. In-person enrollments
      # resolve both the residential and the document address, so this is the unit failover retries.
      def resolve_identity(vendor:, applicant_pii:, current_sp:, ipp_enrollment_in_progress:,
                           timer:)
        residential_resolution_result = residential_address_plugin(vendor).call(
          applicant_pii:, current_sp:, ipp_enrollment_in_progress:, timer:,
        )
        resolution_result = state_id_address_plugin(vendor).call(
          applicant_pii:, current_sp:, ipp_enrollment_in_progress:, timer:,
          residential_address_resolution_result: residential_resolution_result
        )
        { residential_resolution_result:, resolution_result:, proofing_vendor: vendor }
      end

      def residential_address_plugin(vendor = proofing_vendor)
        @residential_address_plugins ||= {}
        @residential_address_plugins[vendor] ||= Plugins::ResidentialAddressPlugin.new(
          proofer: create_proofer(vendor),
          sp_cost_token: sp_cost_token(vendor),
        )
      end

      def state_id_address_plugin(vendor = proofing_vendor)
        @state_id_address_plugins ||= {}
        @state_id_address_plugins[vendor] ||= Plugins::StateIdAddressPlugin.new(
          proofer: create_proofer(vendor),
          sp_cost_token: sp_cost_token(vendor),
        )
      end

      def create_proofer(vendor = proofing_vendor)
        case vendor
        when :instant_verify then create_instant_verify_proofer
        when :instant_verify_ddp then create_instant_verify_ddp_proofer
        when :mock then create_mock_proofer
        when :socure_kyc then create_socure_proofer
        else
          raise InvalidProofingVendorError, "#{vendor} is not a valid proofing vendor"
        end
      end

      def create_instant_verify_proofer
        Proofing::LexisNexis::InstantVerify::Proofer.new(
          LexisNexis::Config.new(
            instant_verify_workflow: IdentityConfig.store.lexisnexis_instant_verify_workflow,
            account_id: IdentityConfig.store.lexisnexis_account_id,
            base_url: IdentityConfig.store.lexisnexis_base_url,
            username: IdentityConfig.store.lexisnexis_username,
            password: IdentityConfig.store.lexisnexis_password,
            hmac_key_id: IdentityConfig.store.lexisnexis_hmac_key_id,
            hmac_secret_key: IdentityConfig.store.lexisnexis_hmac_secret_key,
            request_mode: IdentityConfig.store.lexisnexis_request_mode,
          ),
          @analytics,
        )
      end

      def create_instant_verify_ddp_proofer
        Proofing::LexisNexis::Ddp::Proofers::InstantVerifyProofer.new(
          api_key: IdentityConfig.store.lexisnexis_threatmetrix_api_key,
          org_id: IdentityConfig.store.lexisnexis_threatmetrix_org_id,
          base_url: IdentityConfig.store.lexisnexis_threatmetrix_base_url,
          ddp_policy: IdentityConfig.store.lexisnexis_instant_verify_ddp_policy,
        )
      end

      def create_mock_proofer
        Proofing::Mock::ResolutionMockClient.new
      end

      def create_socure_proofer
        Proofing::Socure::IdPlus::Proofers::KycProofer.new(
          Proofing::Socure::IdPlus::Config.new(
            user_uuid:,
            user_email:,
            api_key: IdentityConfig.store.socure_idplus_api_key,
            base_url: IdentityConfig.store.socure_idplus_base_url,
            timeout: IdentityConfig.store.socure_idplus_timeout_in_seconds,
          ),
          @analytics,
        )
      end

      def sp_cost_token(vendor = proofing_vendor)
        PROOFING_VENDOR_SP_COST_TOKENS[vendor].tap do |token|
          if !token.present?
            raise InvalidProofingVendorError,
                  "No cost token present for proofing vendor #{vendor}"
          end
        end
      end
    end
  end
end
