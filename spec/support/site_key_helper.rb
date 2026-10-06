module SiteKeyHelper
  # Written out independently of SiteKeys::Sealer so that specs pin the wire format a relying
  # party's browser implements.
  SITE_KEY_WRAP_INFO = 'login.gov site key wrap v1'.freeze

  CreatedSiteKeyRoot = Struct.new(:root, :recovery_code, keyword_init: true)

  def create_site_key_root(user, password: user.password, acknowledge: true)
    vault = SiteKeys::Vault.new(user:, user_session: {})
    root = vault.unlock(password, create: true)
    recovery_code = vault.pending_recovery_code
    vault.acknowledge_recovery_code if acknowledge
    user.reload
    CreatedSiteKeyRoot.new(root:, recovery_code:)
  end

  def derive_site_key(root, issuer)
    OpenSSL::KDF.hkdf(
      root, salt: SiteKeys::Vault::SITE_KEY_SALT, info: issuer, length: 32, hash: 'SHA256'
    )
  end

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

  def site_key_jwk_param(key)
    jwk = JWT::JWK.new(key).export.slice(:kty, :crv, :x, :y)
    Base64.urlsafe_encode64(jwk.to_json, padding: false)
  end
end
