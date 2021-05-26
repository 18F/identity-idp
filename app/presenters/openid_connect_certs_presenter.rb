class OpenidConnectCertsPresenter
  def certs
    { keys: keys.map { |key| JWT::JWK.new(key).export } }
  end

  private

  def keys
    [AppArtifacts.store.oidc_public_key]
  end
end
