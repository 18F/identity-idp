# frozen_string_literal: true

class OpenidConnectCertsPresenter
  def certs
    {
      keys: keys,
    }
  end

  private

  def keys
    [AppArtifacts.store.oidc_public_key].map do |key|
      {
        alg: 'RS256',
        use: 'sig',
      }.merge(JWT::JWK.new(key).export)
    end
  end
end
