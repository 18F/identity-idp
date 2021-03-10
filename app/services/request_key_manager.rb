class RequestKeyManager
  cattr_accessor :public_key do
    OpenSSL::PKey::RSA.new(AppArtifacts.store.oidc_public_key)
  end

  cattr_accessor :private_key do
    OpenSSL::PKey::RSA.new(AppArtifacts.store.oidc_private_key)
  end
end
