# frozen_string_literal: true

module SiteKeys
  # Encrypts a site key to the relying party's browser key with ECDH-ES, HKDF-SHA256 and
  # AES-256-GCM. The HKDF info and the GCM additional data both carry the format version and
  # the client_id.
  class Sealer
    VERSION = 1
    WRAP_INFO = "login.gov site key wrap v#{VERSION}".freeze
    KEY_BYTES = 32

    def initialize(issuer:, recipient:)
      @issuer = issuer.to_s
      @recipient = recipient
    end

    # @return [String] base64url JSON `{v, epk, iv, ct}`
    def seal(key:, email: nil, emails: nil)
      validate!(key)
      ephemeral = OpenSSL::PKey::EC.generate('prime256v1')
      cipher = OpenSSL::Cipher.new('aes-256-gcm').encrypt
      cipher.key = kek(ephemeral.derive(recipient))
      iv = cipher.random_iv
      cipher.auth_data = context
      plaintext = { k: encode(key), email:, emails: }.compact.to_json
      ciphertext = cipher.update(plaintext) + cipher.final + cipher.auth_tag

      encode(
        {
          v: VERSION,
          epk: JWT::JWK.new(ephemeral).export.slice(:kty, :crv, :x, :y),
          iv: encode(iv),
          ct: encode(ciphertext),
        }.to_json,
      )
    end

    private

    attr_reader :issuer, :recipient

    def validate!(key)
      raise SealError, 'site key must be 32 bytes' unless key.bytesize == KEY_BYTES
      unless recipient.is_a?(OpenSSL::PKey::EC) && recipient.group.curve_name == 'prime256v1'
        raise SealError, 'recipient must be a P-256 key'
      end
    end

    def context
      "#{WRAP_INFO}\n#{issuer}"
    end

    def kek(shared_secret)
      OpenSSL::KDF.hkdf(shared_secret, salt: '', info: context, length: 32, hash: 'SHA256')
    end

    def encode(bytes)
      Base64.urlsafe_encode64(bytes, padding: false)
    end
  end
end
