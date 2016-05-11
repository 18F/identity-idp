module Figaro
  # rubocop:disable Style/RaiseArgs
  def require_keys(*keys)
    missing_keys = keys.flatten - (::ENV.keys + secret_keys)
    fail MissingKeys.new(missing_keys) if missing_keys.any?
  end
  # rubocop:enable Style/RaiseArgs

  private

  def secret_keys
    ::Rails.application.secrets.keys.map(&:to_s)
  end
end

Figaro.require_keys(
  'allow_third_party_auth', 'domain_name', 'idp_sso_target_url', 'pt_mode',
  'saml_passphrase', 'saml_cert', 'saml_idp_cert', 'saml_client_private_key',
  'saml_private_key', 'twilio_accounts'
)
