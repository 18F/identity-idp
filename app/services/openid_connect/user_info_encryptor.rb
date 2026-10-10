# frozen_string_literal: true

module OpenidConnect
  # Encrypts a userinfo response for a service provider that has opted in to receive its claims
  # as an encrypted JWT (OpenID Connect Core 1.0 §5.3.2, "Successful UserInfo Response").
  #
  # The whole claims object is serialized as JSON and becomes the plaintext of one compact JWE
  # (RFC 7516 §3.1, §7.1): the content encryption key is wrapped with the service provider's
  # RSA public key under RSA-OAEP-256 (RFC 7518 §4.3) and the claims are encrypted with
  # AES-256-GCM (RFC 7518 §5.3). The JWE header carries only `alg` and `enc`; the claims are not
  # also signed inside the JWE, and no `kid` is set because a service provider holds exactly one
  # registered key and the decrypting party is the key's owner. The response is then served as
  # `application/jwt` instead of `application/json`.
  #
  # The key is the public key of the service provider's registered signing certificate
  # (ServiceProvider#userinfo_encryption_key). When a record has opted in but no usable key
  # exists, NoUsableKeyError is raised and the caller must not fall back to plain JSON: a partner
  # that asked for encryption must never receive a person's attributes in the clear because its
  # record is misconfigured.
  class UserInfoEncryptor
    ALG = 'RSA-OAEP-256'
    ENC = 'A256GCM'

    class NoUsableKeyError < StandardError; end

    # @param service_provider [ServiceProvider] the opted-in record the response is for
    # @param claims [Hash] the userinfo claims OpenidConnectUserInfoPresenter#user_info returns
    def initialize(service_provider:, claims:)
      @service_provider = service_provider
      @claims = claims
    end

    # @return [String] the compact-serialized JWE of the claims
    # @raise [NoUsableKeyError] when the record has no public key to encrypt to
    def call
      public_key = service_provider.userinfo_encryption_key
      # RSA-OAEP-256 wraps the content key with an RSA key; a certificate carrying any other key
      # type cannot be used, so it is as good as no key.
      unless public_key.is_a?(OpenSSL::PKey::RSA)
        raise NoUsableKeyError,
              "no usable RSA public key registered for #{service_provider.issuer}"
      end

      JWE.encrypt(claims.to_json, public_key, alg: ALG, enc: ENC)
    end

    private

    attr_reader :service_provider, :claims
  end
end
