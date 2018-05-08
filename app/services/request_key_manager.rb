class RequestKeyManager
  def self.read_key_file(key_file, passphrase)
    OpenSSL::PKey::RSA.new(
      File.read(key_file),
      passphrase
    )
  rescue OpenSSL::PKey::RSAError
    raise OpenSSL::PKey::RSAError, "Failed to load #{key_file.inspect}. Bad passphrase?"
  end
  private_class_method :read_key_file

  cattr_accessor :private_key do
    key_file = Rails.root.join('keys', 'saml.key.enc')
    read_key_file(key_file, Figaro.env.saml_passphrase)
  end

  cattr_accessor :gpo_ssh_key do
    key_file = Rails.root.join('keys', 'equifax_rsa')
    read_key_file(key_file, Figaro.env.gpo_ssh_passphrase)
  end
end
