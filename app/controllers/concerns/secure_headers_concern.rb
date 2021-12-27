module SecureHeadersConcern
  extend ActiveSupport::Concern

  def apply_secure_headers_override
    return if stored_url_for_user.blank?

    authorize_form = OpenidConnectAuthorizeForm.new(authorize_params)

    return unless authorize_form.valid?

    override_csp_with_uris
  end

  def override_csp_with_uris
    override_content_security_policy_directives(
      form_action: csp_uris,
      preserve_schemes: true,
    )
  end

  def csp_uris
    return ["'self'"] if stored_url_for_user.blank?
    # Returns fully formed CSP array w/"'self'" and redirect_uris
    SecureHeadersAllowList.csp_with_sp_redirect_uris(
      authorize_params[:redirect_uri],
      decorated_session.sp_redirect_uris,
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
