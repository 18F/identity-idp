# frozen_string_literal: true

module ThreatMetrixHelper
  THREAT_METRIX_URL = 'https://h.online-metrix.net/fp'
  NO_THREAT_METRIX_VARIABLES = {
    threatmetrix_session_id: nil,
    threatmetrix_javascript_urls: [],
    threatmetrix_iframe_url: nil,
  }.freeze

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

  def threatmetrix_variables(hybrid_flow: false)
    if hybrid_flow
      hybrid_flow_threatmetrix_variables
    else
      default_account_creation_threatmetrix_variables
    end
  end

  def account_creation_threatmetrix_bootstrap_needed?
    account_creation_threatmetrix_collection_enabled? &&
      user_session[:in_account_creation_flow] == true &&
      !account_creation_threatmetrix_bootstrapped?
  end

  def account_creation_threatmetrix_variables
    return NO_THREAT_METRIX_VARIABLES unless account_creation_threatmetrix_bootstrap_needed?

    user_session[:sign_up_threatmetrix_bootstrapped] = true

    build_threatmetrix_variables(generate_threatmetrix_session_id)
  end

  private

  def default_account_creation_threatmetrix_variables
    return {} unless account_creation_threatmetrix_collection_enabled?

    build_threatmetrix_variables(generate_threatmetrix_session_id)
  end

  def hybrid_flow_threatmetrix_variables
    return {} unless FeatureManagement.proofing_device_hybrid_profiling_collecting_enabled?

    build_threatmetrix_variables(generate_hybrid_flow_threatmetrix_session_id)
  end

  def build_threatmetrix_variables(session_id)
    {
      threatmetrix_session_id: session_id,
      threatmetrix_javascript_urls: threatmetrix_javascript_urls(session_id),
      threatmetrix_iframe_url: threatmetrix_iframe_url(session_id),
    }
  end

  def account_creation_threatmetrix_collection_enabled?
    FeatureManagement.account_creation_device_profiling_collecting_enabled?
  end

  def account_creation_threatmetrix_bootstrapped?
    user_session[:sign_up_threatmetrix_bootstrapped]
  end

  def generate_threatmetrix_session_id
    user_session[:sign_up_threatmetrix_session_id] ||= SecureRandom.uuid
  end

  def generate_hybrid_flow_threatmetrix_session_id
    session[:hybrid_flow_threatmetrix_session_id] ||= SecureRandom.uuid
  end
end
