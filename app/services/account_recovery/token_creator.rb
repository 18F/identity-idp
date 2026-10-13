# frozen_string_literal: true

module AccountRecovery
  # Generates the single-use recovery token for an account-preserving MFA
  # recovery request.
  #
  # The raw token is returned to the caller exactly once, so it can be placed in
  # the emailed recovery link. Only a keyed fingerprint is persisted. The raw
  # token must never be logged, stored, or included in analytics.
  class TokenCreator
    # 32 url-safe base64 characters, well above the 128 bits of entropy the ADR
    # requires.
    TOKEN_BYTE_LENGTH = 32

    Token = Struct.new(:raw, :fingerprint, :expires_at, keyword_init: true)

    # @return [Token]
    def self.call
      new.call
    end

    # @return [Token]
    def call
      raw = SecureRandom.urlsafe_base64(TOKEN_BYTE_LENGTH)

      Token.new(
        raw: raw,
        fingerprint: self.class.fingerprint(raw),
        expires_at: Time.zone.now + valid_for,
      )
    end

    # @param raw_token [String]
    # @return [String] keyed fingerprint suitable for persistence and lookup
    def self.fingerprint(raw_token)
      Pii::Fingerprinter.fingerprint(raw_token)
    end

    private

    def valid_for
      IdentityConfig.store.account_recovery_token_valid_for_hours.hours
    end
  end
end
