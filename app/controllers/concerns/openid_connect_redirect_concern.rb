# frozen_string_literal: true

module OpenidConnectRedirectConcern
  # We do not include Content-Security-Policy form-action headers if they are
  # configured to be disabled and we are not using a server-side redirect.
  def form_action_csp_disabled_and_not_server_side_redirect?
    !IdentityConfig.store.openid_connect_content_security_form_action_enabled &&
      IdentityConfig.store.openid_connect_redirect != 'server_side'
  end
end
