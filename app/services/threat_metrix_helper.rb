# frozen_string_literal: true

module ThreatMetrixHelper
  THREAT_METRIX_URL = 'https://h.online-metrix.net/fp'

  # @return [Array<String>]
  def threatmetrix_javascript_urls(session_id)
    sources = if IdentityConfig.store.lexisnexis_threatmetrix_mock_enabled
                Rails.application.config.asset_sources.get_sources('mock-device-profiling')
              else
                ["#{THREAT_METRIX_URL}/tags.js"]
              end

    sources.map do |source|
      UriService.add_params(
        source,
        org_id: IdentityConfig.store.lexisnexis_threatmetrix_org_id,
        session_id: session_id,
      )
    end
  end

  def threatmetrix_iframe_url(session_id)
    source = if IdentityConfig.store.lexisnexis_threatmetrix_mock_enabled
               Rails.application.routes.url_helpers.test_device_profiling_iframe_url
             else
               "#{THREAT_METRIX_URL}/tags"
             end

    UriService.add_params(
      source,
      org_id: IdentityConfig.store.lexisnexis_threatmetrix_org_id,
      session_id: session_id,
    )
  end

  def threatmetrix_variables
    return {} unless FeatureManagement.account_creation_device_profiling_collecting_enabled?
    session_id = generate_threatmetrix_session_id

    {
      threatmetrix_session_id: session_id,
      threatmetrix_javascript_urls: threatmetrix_javascript_urls(session_id),
      threatmetrix_iframe_url: threatmetrix_iframe_url(session_id),
    }
  end

  def generate_threatmetrix_session_id
    user_session[:sign_up_threatmetrix_session_id] ||= SecureRandom.uuid
  end
end
