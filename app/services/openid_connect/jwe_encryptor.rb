# frozen_string_literal: true

module OpenidConnect
  # Encrypts a payload for one service provider as a compact JWE (RFC 7516 §3.1, §7.1) that only
  # that service provider can read.
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
