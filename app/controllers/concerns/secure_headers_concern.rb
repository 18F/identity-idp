module SecureHeadersConcern
  extend ActiveSupport::Concern

  def apply_secure_headers_override(oidc_authorize_form: nil)
    return if oidc_authorize_form.nil? && stored_url_for_user.blank?

    authorize_form = oidc_authorize_form || OpenidConnectAuthorizeForm.new(authorize_params)
    return unless authorize_form.valid?

    redirect_uri = authorize_form.redirect_uri
    redirect_uris = csp_uris(
      redirect_uris: authorize_form.service_provider.redirect_uris,
      requested_redirect_uri: redirect_uri,
    )
    override_form_action_csp(redirect_uris)
  end

  def override_form_action_csp(uris)
    policy = current_content_security_policy
    policy.form_action(*uris)
    request.content_security_policy = policy
  end

  def csp_uris(redirect_uris: nil, requested_redirect_uri: nil)
    return ["'self'"] if stored_url_for_user.blank? && redirect_uris.nil?
    # Returns fully formed CSP array w/"'self'" and redirect_uris
    SecureHeadersAllowList.csp_with_sp_redirect_uris(
      requested_redirect_uri || authorize_params[:redirect_uri],
      redirect_uris || decorated_session.sp_redirect_uris,
    )
  end

  def authorize_params
    return @authorize_params if defined?(@authorize_params)
    @authorize_params = UriService.params(stored_url_for_user)
  end

  private

  def stored_url_for_user
    return @stored_url_for_user if defined?(@stored_url_for_user)
    @stored_url_for_user = sp_session_request_url_with_updated_params
  end
end
