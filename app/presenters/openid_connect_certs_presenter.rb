# frozen_string_literal: true

class OpenidConnectCertsPresenter
  KEYS = [
    AppArtifacts.store.oidc_primary_public_key,
    AppArtifacts.store.oidc_secondary_public_key,
  ].compact.map do |key|
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
