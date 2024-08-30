# frozen_string_literal: true

module OpenidConnectRedirectConcern
  def oidc_redirect_method(issuer:, user_uuid:)
    user_redirect_method_override =
      IdentityConfig.store.openid_connect_redirect_uuid_override_map[user_uuid]

    sp_redirect_method_override =
      IdentityConfig.store.openid_connect_redirect_issuer_override_map[issuer]

    user_redirect_method_override || sp_redirect_method_override ||
      IdentityConfig.store.openid_connect_redirect
  end

  # We do not include Content-Security-Policy form-action headers if they are
  # configured to be disabled and we are not using a server-side redirect.
  def form_action_csp_disabled_and_not_server_side_redirect?(issuer:, user_uuid:)
    !IdentityConfig.store.openid_connect_content_security_form_action_enabled &&
      oidc_redirect_method(
        issuer: issuer,
        user_uuid: user_uuid,
      ) != 'server_side'
  end
end
