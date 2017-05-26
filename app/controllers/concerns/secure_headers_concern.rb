module SecureHeadersConcern
  extend ActiveSupport::Concern

  def apply_secure_headers_override
    return unless stored_url_for_user&.start_with?(openid_connect_authorize_url)

    authorize_params = URIService.params(stored_url_for_user)

    authorize_form = OpenidConnectAuthorizeForm.new(authorize_params)

    return unless authorize_form.valid?

    override_content_security_policy_directives(
      form_action: ["'self'", authorize_form.sp_redirect_uri].compact,
      preserve_schemes: true
    )
  end

  def stored_url_for_user
    sp_session[:request_url]
  end
end
