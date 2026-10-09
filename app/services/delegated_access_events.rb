# frozen_string_literal: true

# Fraud-signal events for delegated access, delivered through the Attempts API to the agency
# whose application a service provider acts at.
#
# An agency receives these events under its own Attempts issuer, encrypted to its own key, so it
# can see the sign-in behind a delegated token the way it would see a direct sign-in. Every
# delegated event carries `delegation_id` (the same value the token's verification returns, so the
# agency can join events to API calls) and `actor_issuer` (the service provider acting for the
# person), and attributes the person by their identifier at the agency, never by the service
# provider's.
#
# Delivery is best-effort and additive: a failure or an agency that is not enrolled never affects
# the person's sign-in, the service provider's own Attempts events or the token request that
# produced the event.
class DelegatedAccessEvents
  # Delivery to agencies is off unless delegated access is on, this delivery is switched on
  # separately, and the Attempts API itself is on.
  def self.enabled?
    IdentityConfig.store.token_exchange_enabled &&
      IdentityConfig.store.token_exchange_attempts_delivery_enabled &&
      IdentityConfig.store.attempts_api_enabled
  end
end
