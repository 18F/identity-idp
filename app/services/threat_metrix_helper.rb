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
end
