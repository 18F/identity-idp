# frozen_string_literal: true

class RevokeServiceProviderConsent
  attr_reader :identity, :now

  def initialize(identity, now: Time.zone.now)
    @identity = identity
    @now = now
  end

  def call
    identity.update!(deleted_at: now, verified_attributes: nil)
    TokenExchange::RefreshTokenRevoker.revoke_for_actor(
      user_id: identity.user_id,
      actor_issuer: identity.service_provider,
    )
  end
end
