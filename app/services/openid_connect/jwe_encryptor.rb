# frozen_string_literal: true

module OpenidConnect
  # Encrypts a payload for one service provider as a compact JWE (RFC 7516 §3.1, §7.1) that only
  # that service provider can read.
  #
  # The content encryption key is wrapped with the RSA public key of the service provider's first
  # registered certificate under RSA-OAEP (RFC 7518 §4.3), and the payload is encrypted with
  # AES-256-GCM (RFC 7518 §5.3) after DEFLATE compression (RFC 7516 §4.1.3). The header names the
  # key by its JWK thumbprint (`kid`, RFC 7638), so a partner holding more than one key knows which
  # to use. By default it carries `typ: JWT`, because a signed token or a bare claims set is a JWT
  # (RFC 7519 §5.1); a caller sealing something else, such as an image, passes `typ: nil` and the
  # payload's media type as `cty` (RFC 7516 §4.1.12) so the recipient knows what it decrypted.
  #
  # The certificate is the one the service provider's `private_key_jwt` client assertions are
  # verified against (RFC 7523), so the partner decrypts with a key it already holds. A record with
  # no readable RSA certificate cannot be encrypted to; NoUsableKeyError is raised and the caller
  # must not fall back to sending the payload in the clear.
  class JweEncryptor
    ALG = 'RSA-OAEP'
    ENC = 'A256GCM'
    ZIP = 'DEF'

    class NoUsableKeyError < StandardError; end

    def self.encrypt(payload, service_provider:, typ: 'JWT', cty: nil)
      new(service_provider:).encrypt(payload, typ:, cty:)
    end

    def initialize(service_provider:)
      @service_provider = service_provider
    end

    def encrypt(payload, typ: 'JWT', cty: nil)
      header = { zip: ZIP, alg: ALG, enc: ENC, kid: }
      header[:typ] = typ if typ
      header[:cty] = cty if cty
      JWE.encrypt(payload, public_key, **header)
    end

    private

    attr_reader :service_provider

    def public_key
      @public_key ||= begin
        key = service_provider.ssl_certs.first&.public_key
        unless key.is_a?(OpenSSL::PKey::RSA)
          raise NoUsableKeyError,
                "no usable RSA public key registered for #{service_provider.issuer}"
        end

        key
      end
    end

    def kid
      JWT::JWK.new(public_key).kid
    end
  end
end
