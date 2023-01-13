module SecureHeadersConcern
  extend ActiveSupport::Concern

  def apply_secure_headers_override(oidc_authorize_form: nil)
    return if stored_url_for_user.blank?

    authorize_form = oidc_authorize_form || OpenidConnectAuthorizeForm.new(authorize_params)
    return unless authorize_form.valid?

    redirect_uris = csp_uris(redirect_uris: authorize_form.service_provider.redirect_uris)
    override_form_action_csp(redirect_uris)
  end

  def override_form_action_csp(uris)
    policy = current_content_security_policy
    policy.form_action(*uris)
    request.content_security_policy = policy
  end

  def csp_uris(redirect_uris: nil)
    return ["'self'"] if stored_url_for_user.blank? && redirect_uris.nil?
    redirect_uris ||= decorated_session.sp_redirect_uris
    # Returns fully formed CSP array w/"'self'" and redirect_uris
    SecureHeadersAllowList.csp_with_sp_redirect_uris(
      authorize_params[:redirect_uri],
      redirect_uris,
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
