# frozen_string_literal: true

class AttemptsApiCertsPresenter
  def certs
    {
      keys: [key],
    }
  end

  private

  def key
    if signing_key.present?
      cert = OpenSSL::PKey::EC.new(signing_key)
      {
        alg: 'ES256',
        use: 'sig',
      }.merge(JWT::JWK::EC.new(OpenSSL::PKey::EC.new(cert.public_to_pem)).export)
    else
      {}
    end
  end

  def signing_key
    IdentityConfig.store.attempts_api_signing_key
  end
end
