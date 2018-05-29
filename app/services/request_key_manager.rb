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

  cattr_accessor :public_key do
    crt_file = Rails.root.join('certs', 'saml.crt')
    cert = OpenSSL::X509::Certificate.new(File.read(crt_file))
    cert.public_key
  end

  cattr_accessor :private_key do
    key_file = Rails.root.join('keys', 'saml.key.enc')
    read_key_file(key_file, Figaro.env.saml_passphrase)
  end

  cattr_accessor :equifax_ssh_key do
    key_file = Rails.root.join('keys', 'equifax_rsa')
    read_key_file(key_file, Figaro.env.equifax_ssh_passphrase)
  end
end
