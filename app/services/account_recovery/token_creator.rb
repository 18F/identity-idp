# frozen_string_literal: true

module AccountRecovery
  # Generates the single-use recovery token for an account-preserving MFA
  # recovery request.
  class TokenCreator
    Token = Struct.new(:raw, :fingerprint, :expires_at, keyword_init: true)

    # @return [Token]
    def self.call
      new.call
    end

    # @return [Token]
    def call
      raw = SecureRandom.uuid

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
