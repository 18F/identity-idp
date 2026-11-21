# frozen_string_literal: true

module SiteKeys
  # A person's site key: a P-256 key pair (RFC 7518 §6.2). The 32-byte private scalar is the
  # secret that is wrapped under secrets the person holds and released to the service provider's
  # page; the public key is stored in the clear.
  class KeyPair
    CURVE = 'prime256v1'
    PRIVATE_BYTES = 32

    def self.generate
      new(OpenSSL::PKey::EC.generate(CURVE))
    end

    # @raise [ArgumentError] when the bytes are not a valid P-256 private scalar
    def self.from_private_bytes(bytes)
      raise ArgumentError, 'site key must be 32 bytes' unless bytes&.bytesize == PRIVATE_BYTES

      group = OpenSSL::PKey::EC::Group.new(CURVE)
      scalar = OpenSSL::BN.new(bytes, 2)
      unless scalar > 0 && scalar < group.order
        raise ArgumentError, 'site key is not a valid P-256 private key'
      end

      new(OpenSSL::PKey::EC.new(private_key_der(group, scalar, bytes)))
    end

    # SEC 1 ECPrivateKey: the scalar, the named curve and the public point, so OpenSSL loads a
    # complete key from the 32 stored bytes.
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

    # @return [String] the 32-byte private scalar, left-padded so it always wraps to 32 bytes
    def private_bytes
      key.private_key.to_s(2).rjust(PRIVATE_BYTES, "\0")
    end

    # @return [Hash] the public JWK: `kty`, `crv`, `x`, `y`
    def public_jwk
      JWT::JWK.new(public_key).export.slice(:kty, :crv, :x, :y).stringify_keys
    end

    # @return [Hash] the private JWK: the public members plus `d` (RFC 7518 §6.2.2)
    def private_jwk
      JWT::JWK.new(key).export(include_private: true).slice(:kty, :crv, :x, :y, :d).stringify_keys
    end

    # @return [OpenSSL::PKey::EC]
    def public_key
      OpenSSL::PKey::EC.new(key.public_to_der)
    end
  end
end
