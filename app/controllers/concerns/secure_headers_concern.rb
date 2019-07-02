module SecureHeadersConcern
  extend ActiveSupport::Concern

  def apply_secure_headers_override
    return if stored_url_for_user.blank?

    authorize_params = URIService.params(stored_url_for_user)
    authorize_form = OpenidConnectAuthorizeForm.new(authorize_params)

    return unless authorize_form.valid?

    redirect_uri = authorize_params[:redirect_uri]

    override_content_security_policy_directives(
      form_action: ["'self'", redirect_uri].compact,
      preserve_schemes: true,
    )
  end

  private

  def stored_url_for_user
    sp_session_request_url_without_prompt_login
  end
end
