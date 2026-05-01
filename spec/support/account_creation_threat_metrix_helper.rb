module AccountCreationThreatMetrixHelper
  THREATMETRIX_URL = 'https://h.online-metrix.net/fp'.freeze
  THREATMETRIX_ORG_ID = 'org1'.freeze

  def stub_account_creation_threatmetrix(tmx_session_id:, org_id: THREATMETRIX_ORG_ID)
    allow(FeatureManagement).to receive(:account_creation_device_profiling_collecting_enabled?)
      .and_return(true)
    allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_org_id).and_return(org_id)
    allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_mock_enabled)
      .and_return(false)
    controller.user_session[:in_account_creation_flow] = true
    controller.user_session[:sign_up_threatmetrix_session_id] = tmx_session_id
  end

  def account_creation_threatmetrix_locals(tmx_session_id:, org_id: THREATMETRIX_ORG_ID)
    {
      threatmetrix_session_id: tmx_session_id,
      threatmetrix_javascript_urls: [
        "#{THREATMETRIX_URL}/tags.js?org_id=#{org_id}&session_id=#{tmx_session_id}",
      ],
      threatmetrix_iframe_url:
        "#{THREATMETRIX_URL}/tags?org_id=#{org_id}&session_id=#{tmx_session_id}",
    }
  end

  def empty_account_creation_threatmetrix_locals
    {
      threatmetrix_session_id: nil,
      threatmetrix_javascript_urls: [],
      threatmetrix_iframe_url: nil,
    }
  end
end
