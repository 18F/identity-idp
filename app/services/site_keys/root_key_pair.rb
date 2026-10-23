# frozen_string_literal: true

module SiteKeys
  # A user's site key root as a P-256 key pair. The private scalar is the secret that site keys
  # are derived from and that is wrapped under user-held secrets; the public key can be stored
  # in the clear so data can later be sealed to the user without unlocking the root.
  class RootKeyPair
    CURVE = 'prime256v1'
    PRIVATE_BYTES = 32

    def self.generate
      new(OpenSSL::PKey::EC.generate(CURVE))
    end

    # @raise [SealError] when the bytes are not a valid P-256 private scalar
    def self.from_private_bytes(bytes)
      raise SealError, 'site key root must be 32 bytes' unless bytes&.bytesize == PRIVATE_BYTES

      group = OpenSSL::PKey::EC::Group.new(CURVE)
      scalar = OpenSSL::BN.new(bytes, 2)
      unless scalar > 0 && scalar < group.order
        raise SealError, 'site key root is not a valid P-256 private key'
      end

      new(OpenSSL::PKey::EC.new(private_key_der(group, scalar, bytes)))
    end

    def self.private_key_der(group, scalar, bytes)
      point = group.generator.mul(scalar)
      OpenSSL::ASN1::Sequence.new(
        [
          OpenSSL::ASN1::Integer.new(1),
          OpenSSL::ASN1::OctetString.new(bytes),
          OpenSSL::ASN1::ObjectId.new(CURVE, 0, :EXPLICIT),
          OpenSSL::ASN1::BitString.new(point.to_octet_string(:uncompressed), 1, :EXPLICIT),
        ],
      ).to_der
    end

    private_class_method :new, :private_key_der

    attr_reader :key

    def initialize(key)
      @key = key
    end

    # @return [String] the 32-byte private scalar
    def private_bytes
      key.private_key.to_s(2).rjust(PRIVATE_BYTES, "\0")
    end

    # @return [String] base64url JSON of the public JWK, in the format RecipientJwk parses
    def public_jwk
      jwk = JWT::JWK.new(public_key).export.slice(:kty, :crv, :x, :y)
      Base64.urlsafe_encode64(jwk.to_json, padding: false)
    end

    # @return [OpenSSL::PKey::EC]
    def public_key
      OpenSSL::PKey::EC.new(key.public_to_der)
    end
  end
end
