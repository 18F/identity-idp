# frozen_string_literal: true

module Proofing
  module Resolution
    module Plugins
      class ThreatMetrixPlugin
        def call(
          applicant_pii:,
          current_sp:,
          request_ip:,
          threatmetrix_session_id:,
          timer:,
          user_email:,
          user_uuid:
        )
          unless FeatureManagement.proofing_device_profiling_collecting_enabled?
            return threatmetrix_disabled_result
          end

          # The API call will fail without a session ID, so do not attempt to make
          # it to avoid leaking data when not required.
          return threatmetrix_id_missing_result if threatmetrix_session_id.blank?
          return threatmetrix_pii_missing_result if applicant_pii.blank?

          ddp_pii = applicant_pii.merge(
            threatmetrix_session_id: threatmetrix_session_id,
            email: user_email,
            request_ip: request_ip,
            uuid: user_uuid,
          )

          timer.time('threatmetrix') do
            proofer.proof(ddp_pii)
          end.tap do |result|
            Db::SpCost::AddSpCost.call(
              current_sp, :threatmetrix,
              transaction_id: result.transaction_id
            )
          end
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
                ddp_policy: IdentityConfig.store.lexisnexis_threatmetrix_policy,
              )
            end
        end

        def threatmetrix_disabled_result
          Proofing::DdpResult.new(
            success: true,
            client: 'tmx_disabled',
            review_status: 'pass',
          )
        end

        def threatmetrix_pii_missing_result
          Proofing::DdpResult.new(
            success: false,
            client: 'tmx_pii_missing',
            review_status: 'reject',
          )
        end

        def threatmetrix_id_missing_result
          Proofing::DdpResult.new(
            success: false,
            client: 'tmx_session_id_missing',
            review_status: 'reject',
          )
        end
      end
    end
  end
end
