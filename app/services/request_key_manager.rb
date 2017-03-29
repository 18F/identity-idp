class RequestKeyManager
  cattr_accessor :private_key do
    OpenSSL::PKey::RSA.new(
      File.read(Rails.root.join('keys', 'saml.key.enc')),
      Figaro.env.saml_passphrase
    )
  end

  cattr_accessor :equifax_ssh_key do
    OpenSSL::PKey::RSA.new(
      File.read(Rails.root.join('keys', 'equifax_rsa')),
      Figaro.env.equifax_ssh_passphrase
    )
  end
end
