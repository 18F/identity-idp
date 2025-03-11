# frozen_string_literal: true

module AccountCreation
  class DeviceProfiling
    attr_reader :request_ip,
                :threatmetrix_session_id,
                :user_email,
                :device_profile_result,
                :uuid_prefix,
                :uuid
    def proof(
      request_ip:,
      threatmetrix_session_id:,
      user_email:,
      uuid_prefix:,
      uuid:
    )
      @request_ip = request_ip
      @threatmetrix_session_id = threatmetrix_session_id
      @user_email = user_email
      @uuid_prefix = uuid_prefix
      @uuid = uuid

      @device_profile_result = device_profile
    end

    def device_profile
      return threatmetrix_disabled_result unless
        FeatureManagement.account_creation_device_profiling_collecting_enabled?
      return threatmetrix_id_missing_result if threatmetrix_session_id.blank?

      proofer.proof(
        threatmetrix_session_id: threatmetrix_session_id,
        email: user_email,
        request_ip: request_ip,
        uuid_prefix: uuid_prefix,
        uuid: uuid,
      )
    end

    def threatmetrix_disabled_result
      Proofing::DdpResult.new(
        success: true,
        client: 'tmx_disabled',
        review_status: 'pass',
      )
    end

    def threatmetrix_id_missing_result
      Proofing::DdpResult.new(
        success: false,
        client: 'tmx_session_id_missing',
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
            ddp_policy: IdentityConfig.store.lexisnexis_threatmetrix_authentication_policy,
          )
        end
    end
  end
end
