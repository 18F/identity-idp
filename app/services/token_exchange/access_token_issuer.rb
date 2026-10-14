# frozen_string_literal: true

module TokenExchange
  class AccessTokenIssuer
    IssuedToken = Struct.new(:token, :expires_in, keyword_init: true)

    def self.issue(subject_token:, target_issuer:, resource:, scope:)
      new(
        subject_token:,
        target_issuer:,
        resource:,
        scope:,
      ).issue
    end

    def initialize(subject_token:, target_issuer:, resource:, scope:)
      @subject_token = subject_token
      @target_issuer = target_issuer
      @resource = resource
      @scope = scope
    end

    def issue
      token = SecureRandom.urlsafe_base64(32)
      expires_in = IdentityConfig.store.token_exchange_access_token_expires_in
      issued_at = Time.zone.now.to_i
      access_token = AccessToken.new(
        id: AccessToken.digest(token),
        identity_uuid: subject_token.identity_uuid,
        broker_issuer: subject_token.broker_issuer,
        target_issuer:,
        resource:,
        scope:,
        issued_at:,
        expires_at: issued_at + expires_in,
      )

      EncryptedRedisStructStorage.store(access_token, expires_in:)

      IssuedToken.new(token:, expires_in:)
    end

    private

    attr_reader :subject_token, :target_issuer, :resource, :scope
  end
end
