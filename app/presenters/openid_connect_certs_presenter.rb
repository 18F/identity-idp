class OpenidConnectCertsPresenter
  def certs
    {
      keys: keys.map { |key| JSON::JWK.new(key) },
    }
  end

  private

  def keys
    [AppArtifacts.store.oidc_public_key]
  end
end
