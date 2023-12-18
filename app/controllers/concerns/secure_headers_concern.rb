module SecureHeadersConcern
  extend ActiveSupport::Concern

  DEV_FRAME_ANCESTORS = [
    'https://developers.login.gov',
  ].freeze

  def apply_secure_headers_override
    return if stored_url_for_user.blank?

    authorize_form = OpenidConnectAuthorizeForm.new(authorize_params)
    return unless authorize_form.valid?

    override_form_action_csp(csp_uris)
  end

  def override_form_action_csp(uris)
    policy = current_content_security_policy
    policy.form_action(*uris)
    if Identity::Hostdata.env == 'dev'
      policy.frame_ancestors(*policy.frame_ancestors, *DEV_FRAME_ANCESTORS)
    end
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
