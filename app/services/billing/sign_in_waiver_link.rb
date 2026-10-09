# frozen_string_literal: true

module Billing
  # The link from a service provider's sign-in to the exchange that may later waive its billing.
  #
  # At the handoff of a sign-in to a service provider approved for delegated access, Login.gov
  # stores the id of the sign-in's billable return-log row under the SHA-256 digest of the access
  # token the service provider is about to receive. When the service provider later presents that
  # token as the subject of a token exchange, the exchange looks the digest up and finds the row
  # to exclude from the service provider's invoice. The token itself is never stored; only its
  # digest is the key, so the entry is useless without the token.
  #
  # Entries are short-lived (`token_exchange_billing_waiver_cache_seconds`, one hour by default):
  # the common case is an exchange seconds after the handoff. An exchange after the entry has
  # lapsed falls back to the database (DelegatedReturnRecorder#sign_in_row_from_database).
  class SignInWaiverLink
    KEY_PREFIX = 'delegated-access-sign-in-return:'

    # @param access_token [String] the access token issued to the service provider
    # @return [String] hex SHA-256 digest, the key suffix
    def self.digest(access_token)
      Digest::SHA256.hexdigest(access_token.to_s)
    end

    # @param access_token [String] the service provider's access token for the sign-in
    # @param sp_return_log_id [Integer] the sign-in's billable return-log row
    def self.write(access_token:, sp_return_log_id:)
      return if access_token.blank? || sp_return_log_id.blank?

      REDIS_POOL.with do |client|
        client.set(KEY_PREFIX + digest(access_token), sp_return_log_id.to_s, ex: ttl_seconds)
      end
    end

    # @param access_token [String] the subject token presented at exchange
    # @return [Integer, nil] the sign-in's return-log row id, or nil when no entry is live
    def self.read(access_token:)
      return nil if access_token.blank?

      raw = REDIS_POOL.with { |client| client.get(KEY_PREFIX + digest(access_token)) }
      raw&.to_i
    end

    def self.ttl_seconds
      IdentityConfig.store.token_exchange_billing_waiver_cache_seconds
    end
  end
end
