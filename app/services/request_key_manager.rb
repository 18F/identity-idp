class RequestKeyManager
  cattr_accessor :private_key do
    OpenSSL::PKey::RSA.new(
      File.read(Rails.root.join('keys/saml.key.enc')),
      Figaro.env.saml_passphrase
    )
  end
end
