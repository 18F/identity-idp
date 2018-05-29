class OpenidConnectCertsPresenter
  def certs
    {
      keys: keys.map { |key| JSON::JWK.new(key) },
    }
  end

  private

  def keys
    [RequestKeyManager.public_key]
  end
end
