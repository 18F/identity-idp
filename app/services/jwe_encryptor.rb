# frozen_string_literal: true

# Encrypts a payload to one RSA public key as a compact JWE (RFC 7516 §7.1): the content key is
# wrapped under RSA-OAEP (RFC 7518 §4.3), the payload is encrypted with AES-256-GCM (RFC 7518 §5.3)
# after DEFLATE compression (RFC 7516 §4.1.3), and the header names the key by its JWK thumbprint
# (`kid`, RFC 7638). Anything but an RSA key raises, so no caller can fall back to the clear.
class JweEncryptor
  ALG = 'RSA-OAEP'
  ENC = 'A256GCM'
  ZIP = 'DEF'

  class NoUsableKeyError < StandardError; end

  # `typ` names what the plaintext is (`JWT` for a token or a claims set, RFC 7519 §5.1); a
  # caller sealing something else passes `typ: nil` and the payload's media type as `cty`
  # (RFC 7516 §4.1.12) so the recipient knows what it decrypted.
  def self.encrypt(payload, public_key:, typ:, cty: nil)
    raise NoUsableKeyError, 'no RSA public key to encrypt to' unless
      public_key.is_a?(OpenSSL::PKey::RSA)

    header = { zip: ZIP, alg: ALG, enc: ENC, kid: JWT::JWK.new(public_key).kid }
    header[:typ] = typ if typ
    header[:cty] = cty if cty

    JWE.encrypt(payload, public_key, **header)
  end
end
