# frozen_string_literal: true

class OpenidConnectCertsPresenter
  def certs
    {
      keys: keys,
    }
  end

  private

  def keys
    keys = [AppArtifacts.store.oidc_public_key, AppArtifacts.store.oidc_public_key_second].compact
    keys.map do |key|
      {
        alg: 'RS256',
        use: 'sig',
      }.merge(JWT::JWK.new(key).export)
    end
  end
end
