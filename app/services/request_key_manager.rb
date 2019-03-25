class RequestKeyManager
  def self.read_key_file(key_file)
    path = Rails.root.join('keys', key_file)
    OpenSSL::PKey::RSA.new(File.read(path))
  end
  private_class_method :read_key_file

  cattr_accessor :public_key do
    read_key_file('oidc.pub')
  end

  cattr_accessor :private_key do
    read_key_file('oidc.key')
  end
end
