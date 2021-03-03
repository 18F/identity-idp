class SpReturnUrlResolver
  attr_reader :sp, :sp_request_url, :view_context

  def initialize(sp:, sp_request_url:)
    @sp = sp
    @sp_request_url = sp_request_url
  end

  def return_to_sp_url
    if oidc_redirect_uri_present?
      oidc_access_denied_redirect_url
    elsif sp.return_to_sp_url.present?
      sp.return_to_sp_url
    else
      inferred_redirect_url
    end
  end

  def failure_to_proof_url
    sp.failure_to_proof_url.presence || return_to_sp_url
  end

  private

  def inferred_redirect_url
    configured_url = sp.redirect_uris&.first || sp.acs_url
    URI.join(configured_url, '/').to_s
  end

  def oidc_access_denied_redirect_url
    UriService.add_params(
      sp_request_url_pararms[:redirect_uri],
      error: 'access_denied',
      state: sp_request_url_pararms[:state],
    )
  end

  def oidc_redirect_uri_present?
    sp_request_url.present? && sp_request_url_pararms[:redirect_uri].present?
  end

  def sp_request_url_pararms
    @sp_request_url_pararms ||= UriService.params(sp_request_url)
  end
end
