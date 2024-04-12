module Idv
  module Resolution
    class ThreatmetrixPlugin
      attr_reader :timer

      def initialize(timer: nil)
        @timer = timer || JobHelpers::Timer.new
      end

      def call(
        input:,
        next_plugin:,
        **
      )

        # When ThreatMetrix _collecting_ is not enabled, we pass through to the next plugin
        # in the stack.
        if !FeatureManagement.proofing_device_profiling_collecting_enabled?
          return next_plugin.call(
            threatmetrix: threatmetrix_disabled_result,
          )
        end

        # When ThreatMetrix is enabled, we _must_ have an associated  session id to check.
        # If we don't, we treat this as a ThreatMetrix rejection (meaning the user will
        # go through fraud review)
        if input_missing_threatmetrix_session_id?(input)
          return next_plugin.call(
            threatmetrix: missing_session_id_result,
          )
        end

        applicant = format_applicant_for_threatmetrix(input)

        if !applicant
          return next_plugin.call(
            threatmetrix: {
              success: false,
              reason: :invalid_applicant,
            },
          )
        end

        proofer_result = timer.time('threatmetrix') do
          proofer.proof(applicant)
        end

        next_plugin.call(
          threatmetrix: proofer_result,
        )
      end

      def format_applicant_for_threatmetrix(input)
        return unless input.state_id && input.other

        {
          **input.state_id.to_h.slice(
            :first_name,
            :last_name,
          ),
          **input.state_id.address.to_h,
          state_id_number: input.state_id.number,
          state_id_jurisdiction: input.state_id.issuing_jurisdiction,
          dob: input.state_id.dob,
          ssn: input.other.ssn,
          email: input.other.email,
          request_ip: input.other.ip,
          uuid_prefix: input.other.sp_app_id,
          threatmetrix_session_id: input.other.threatmetrix_session_id,
        }
      end

      def input_missing_threatmetrix_session_id?(input)
        input&.other&.threatmetrix_session_id.blank?
      end

      def missing_session_id_result
        Proofing::DdpResult.new(
          success: true,
          client: 'tmx_missing_session_id',
          review_status: 'reject',
        )
      end

      def proofer
        @proofer ||=
          if IdentityConfig.store.lexisnexis_threatmetrix_mock_enabled
            Proofing::Mock::DdpMockClient.new
          else
            Proofing::LexisNexis::Ddp::Proofer.new(
              api_key: IdentityConfig.store.lexisnexis_threatmetrix_api_key,
              org_id: IdentityConfig.store.lexisnexis_threatmetrix_org_id,
              base_url: IdentityConfig.store.lexisnexis_threatmetrix_base_url,
            )
          end
      end

      def proof_with_threatmetrix_if_needed(
        applicant_pii:,
        user_email:,
        threatmetrix_session_id:,
        request_ip:,
        timer:
      )
        unless FeatureManagement.proofing_device_profiling_collecting_enabled?
          return threatmetrix_disabled_result
        end

        # The API call will fail without a session ID, so do not attempt to make
        # it to avoid leaking data when not required.
        return threatmetrix_disabled_result if threatmetrix_session_id.blank?

        return threatmetrix_disabled_result unless applicant_pii

        ddp_pii = applicant_pii.dup
        ddp_pii[:threatmetrix_session_id] = threatmetrix_session_id
        ddp_pii[:email] = user_email
        ddp_pii[:request_ip] = request_ip

        timer.time('threatmetrix') do
          lexisnexis_ddp_proofer.proof(ddp_pii)
        end
      end

      def threatmetrix_disabled_result
        Proofing::DdpResult.new(
          success: true,
          client: 'tmx_disabled',
          review_status: 'pass',
        )
      end
    end
  end
end
