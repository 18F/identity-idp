class SpReturnUrlResolver
  attr_reader :service_provider, :oidc_state, :oidc_redirect_uri

  def initialize(service_provider:, oidc_state:, oidc_redirect_uri:)
    @service_provider = service_provider
    @oidc_state = oidc_state
    @oidc_redirect_uri = oidc_redirect_uri
  end

  def return_to_sp_url
    if oidc_redirect_uri.present?
      oidc_access_denied_redirect_url
    elsif service_provider.return_to_sp_url.present?
      service_provider.return_to_sp_url
    else
      inferred_redirect_url
    end
  end

  def failure_to_proof_url
    service_provider.failure_to_proof_url.presence || return_to_sp_url
  end

  private

  def inferred_redirect_url
    configured_url = service_provider.redirect_uris&.first || service_provider.acs_url
    URI.join(configured_url, '/').to_s
  end

  def oidc_access_denied_redirect_url
    UriService.add_params(
      oidc_redirect_uri,
      error: 'access_denied',
      state: oidc_state,
    )
  end
end
