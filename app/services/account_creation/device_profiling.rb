# frozen_string_literal: true

module AccountCreation
  class DeviceProfiling
    attr_reader :request_ip,
                :threatmetrix_session_id,
                :user_email,
                :current_sp,
                :device_profile_result
    def proof(
      request_ip:,
      threatmetrix_session_id:,
      user_email:,
      current_sp: nil
    )
      @request_ip = request_ip
      @threatmetrix_session_id = threatmetrix_session_id
      @user_email = user_email
      @current_sp = current_sp

      @device_profile_result = device_profile
    end

    def device_profile
      return threatmetrix_disabled_result unless
        FeatureManagement.account_creation_device_profiling_collecting_enabled?
      return threatmetrix_id_missing_result if threatmetrix_session_id.blank?
      ddp_params = {}
      ddp_params[:threatmetrix_session_id] = threatmetrix_session_id
      ddp_params[:email] = user_email
      ddp_params[:request_ip] = request_ip

      lexisnexis_ddp_proofer.proof(ddp_params)
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

    def lexisnexis_ddp_proofer
      @lexisnexis_ddp_proofer ||=
        if IdentityConfig.store.lexisnexis_threatmetrix_mock_enabled
          Proofing::Mock::DdpMockClient.new
        else
          AccountCreation::DeviceProfiling::Proofer.new(
            api_key: IdentityConfig.store.lexisnexis_threatmetrix_api_key,
            org_id: IdentityConfig.store.lexisnexis_threatmetrix_org_id,
            base_url: IdentityConfig.store.lexisnexis_threatmetrix_base_url,
          )
        end
    end
  end
end
