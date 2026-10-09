# frozen_string_literal: true

class RevokeServiceProviderConsent
  attr_reader :identity, :now

  def initialize(identity, now: Time.zone.now)
    @identity = identity
    @now = now
  end

  # Disconnecting a service provider ends the connection and every standing approval the person
  # gave that service provider for delegated access: with no connection there is nothing for it
  # to act through.
  def call
    identity.transaction do
      identity.update!(deleted_at: now, verified_attributes: nil)
      TokenExchangeGrant.revoke_all_for!(
        user: identity.user, service_provider_issuer: identity.service_provider,
        reason: 'sp_disconnected', now:
      )
    end
  end
end
