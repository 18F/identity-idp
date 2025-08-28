# frozen_string_literal: true

class AttemptsApiCertsPresenter
  def certs
    {
      keys: [key].compact,
    }
  end

  private

  def key
    if IdentityConfig.store.attempts_api_signing_enabled
      cert = OpenSSL::PKey::EC.new(signing_key)
      {
        alg: 'ES256',
        use: 'sig',
      }.merge(JWT::JWK::EC.new(OpenSSL::PKey::EC.new(cert.public_to_pem)).export)
    end
  end

  def signing_key
    if IdentityConfig.store.attempts_api_signing_key.blank?
      raise AttemptsApi::AttemptEvent::SigningKey::SigningKeyError,
            'Attempts API signing key is not configured'
    end

    IdentityConfig.store.attempts_api_signing_key
  end
end
