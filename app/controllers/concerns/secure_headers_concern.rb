module SecureHeadersConcern
  extend ActiveSupport::Concern

  def apply_secure_headers_override
    return if stored_url_for_user.blank?
    return if IdentityConfig.store.openid_connect_redirect_interstitial_enabled

    authorize_form = OpenidConnectAuthorizeForm.new(authorize_params)
    return unless authorize_form.valid?

    override_form_action_csp(csp_uris)
  end

  def override_form_action_csp(uris)
    policy = current_content_security_policy
    policy.form_action(*uris)
    request.content_security_policy = policy
  end

  def csp_uris
    return ["'self'"] if stored_url_for_user.blank?
    # Returns fully formed CSP array w/"'self'" and redirect_uris
    SecureHeadersAllowList.csp_with_sp_redirect_uris(
      authorize_params[:redirect_uri],
      decorated_sp_session.sp_redirect_uris,
    )
  end

  def authorize_params
    UriService.params(stored_url_for_user)
  end

  private

  def stored_url_for_user
    sp_session_request_url_with_updated_params
  end
end
