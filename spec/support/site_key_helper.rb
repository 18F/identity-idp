module SiteKeyHelper
  # Written out independently of SiteKeys::Sealer so that specs pin the wire format a relying
  # party's browser implements.
  SITE_KEY_WRAP_INFO = 'login.gov site key wrap v1'.freeze

  def open_sealed_site_key(sealed, recipient:, issuer:)
    payload = JSON.parse(Base64.urlsafe_decode64(sealed))
    epk = JWT::JWK.import(payload['epk'].transform_keys(&:to_sym)).public_key
    kek = OpenSSL::KDF.hkdf(
      recipient.derive(epk),
      salt: '',
      info: "#{SITE_KEY_WRAP_INFO}\n#{issuer}",
      length: 32,
      hash: 'SHA256',
    )
    raw = Base64.urlsafe_decode64(payload['ct'])
    cipher = OpenSSL::Cipher.new('aes-256-gcm').decrypt
    cipher.key = kek
    cipher.iv = Base64.urlsafe_decode64(payload['iv'])
    cipher.auth_tag = raw[-16..]
    cipher.auth_data = "#{SITE_KEY_WRAP_INFO}\n#{issuer}"
    JSON.parse(cipher.update(raw[0...-16]) + cipher.final)
  end
end
