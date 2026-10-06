# frozen_string_literal: true

module SiteKeys
  # Parses the `site_key_jwk` authorization parameter: base64url JSON of a P-256 public JWK.
  # WebCrypto `exportKey('jwk')` metadata is accepted; any other member, including `d`, is not.
  module RecipientJwk
    KEY_MEMBERS = %w[kty crv x y].freeze
    ALLOWED_MEMBERS = (KEY_MEMBERS + %w[alg ext key_ops kid use]).freeze
    COORDINATE_BYTES = 32

    # @return [OpenSSL::PKey::EC]
    def self.parse(encoded)
      json = JSON.parse(Base64.urlsafe_decode64(encoded.to_s))
      raise SealError, 'site_key_jwk is not a valid P-256 public JWK' unless valid?(json)

      JWT::JWK.import(json.slice(*KEY_MEMBERS).transform_keys(&:to_sym)).public_key
    rescue ArgumentError, TypeError, JSON::ParserError, JWT::JWKError, OpenSSL::OpenSSLError
      raise SealError, 'site_key_jwk is not a valid P-256 public JWK'
    end

    def self.valid?(json)
      json.is_a?(Hash) &&
        (json.keys - ALLOWED_MEMBERS).empty? &&
        json['kty'] == 'EC' &&
        json['crv'] == 'P-256' &&
        coordinate?(json['x']) &&
        coordinate?(json['y'])
    end

    def self.coordinate?(value)
      value.is_a?(String) && Base64.urlsafe_decode64(value).bytesize == COORDINATE_BYTES
    rescue ArgumentError
      false
    end

    private_class_method :valid?, :coordinate?
  end
end
