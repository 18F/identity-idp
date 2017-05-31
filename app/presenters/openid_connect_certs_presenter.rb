class OpenidConnectCertsPresenter
  def certs
    {
      keys: keys.map { |key| JSON::JWK.new(key) },
    }
  end

  private

  def keys
    [RequestKeyManager.private_key.public_key]
  end
end
