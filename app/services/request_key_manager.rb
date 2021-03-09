class RequestKeyManager
  def self.read_key_file(key_file)
    path = Rails.root.join('keys', key_file)
    OpenSSL::PKey::RSA.new(File.read(path))
  end
  private_class_method :read_key_file

  cattr_accessor :public_key do
    OpenSSL::PKey::RSA.new(AppArtifacts.store.oidc_public_key)
  end

  cattr_accessor :private_key do
    OpenSSL::PKey::RSA.new(AppArtifacts.store.oidc_private_key)
  end
end
