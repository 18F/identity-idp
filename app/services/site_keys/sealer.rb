# frozen_string_literal: true

module SiteKeys
  # Seals a payload to a recipient's P-256 public key as a compact JWE (RFC 7516 §3.1) so that
  # only the holder of the matching private key can open it. Key agreement is ECDH-ES in direct
  # mode (RFC 7518 §4.6): an ephemeral key pair is generated for this one sealing, its public half
  # travels in the `epk` header, and the content-encryption key is the Concat KDF (NIST SP 800-56A
  # §5.8.1, RFC 7518 §4.6.2) of the shared secret. The content is encrypted with AES-256-GCM
  # (RFC 7518 §5.3) and the protected header is the additional authenticated data, so neither the
  # header nor the ciphertext can be altered.
  #
  # The caller passes the recipient key and the client's identifier; the identifier is the
  # PartyVInfo of the KDF (and the `apv` header), so a content key derived for one client cannot be
  # reproduced under another's identifier.
  class Sealer
    CURVE = 'prime256v1'
    ENC = 'A256GCM'
    ALG = 'ECDH-ES'
    KEY_BYTES = 32
    IV_BYTES = 12

    def self.seal(payload, recipient:, client_id:, cty:)
      new(recipient:, client_id:, cty:).seal(payload)
    end

    # @param recipient [OpenSSL::PKey::EC] the recipient's P-256 public key
    def initialize(recipient:, client_id:, cty:)
      @recipient = recipient
      @client_id = client_id.to_s
      @cty = cty
    end

    # @return [String] the compact JWE: five base64url parts separated by dots. ECDH-ES in direct
    #   mode agrees on the content key rather than wrapping one, so the second part is empty.
    def seal(payload)
      ephemeral = OpenSSL::PKey::EC.generate(CURVE)
      header = protected_header(ephemeral)
      aad = encode(header.to_json)
      cek = content_encryption_key(ephemeral)

      cipher = OpenSSL::Cipher.new('aes-256-gcm').encrypt
      cipher.key = cek
      iv = cipher.random_iv
      cipher.auth_data = aad
      ciphertext = cipher.update(payload) + cipher.final

      [aad, '', encode(iv), encode(ciphertext), encode(cipher.auth_tag)].join('.')
    end

    private

    attr_reader :recipient, :client_id, :cty

    def protected_header(ephemeral)
      {
        alg: ALG,
        enc: ENC,
        cty:,
        apv: encode(client_id),
        kid: DpopProofForm.thumbprint(recipient),
        epk: JWT::JWK.new(ephemeral).export.slice(:kty, :crv, :x, :y),
      }
    end

    def content_encryption_key(ephemeral)
      shared_secret = ephemeral.dh_compute_key(recipient.public_key)
      concat_kdf(shared_secret)
    end

    # One round of the Concat KDF with SHA-256 yields the 256-bit content key. For ECDH-ES in
    # direct mode the AlgorithmID is the content-encryption algorithm (`enc`), PartyUInfo is empty
    # and PartyVInfo is the client identifier (RFC 7518 §4.6.2).
    def concat_kdf(shared_secret)
      other_info =
        length_prefixed(ENC) +
        length_prefixed('') +
        length_prefixed(client_id) +
        [KEY_BYTES * 8].pack('N')
      OpenSSL::Digest::SHA256.digest([1].pack('N') + shared_secret + other_info)[0, KEY_BYTES]
    end

    def length_prefixed(value)
      [value.bytesize].pack('N') + value
    end

    def encode(bytes)
      Base64.urlsafe_encode64(bytes, padding: false)
    end
  end
end
