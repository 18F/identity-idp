# frozen_string_literal: true

class OpenidConnectCertsPresenter
  KEYS = Rails.application.config.oidc_public_key_queue.map do |key|
    {
      alg: 'RS256',
      use: 'sig',
    }.merge(JWT::JWK.new(key).export)
  end.freeze

  def certs
    {
      keys: KEYS,
    }
  end
end
