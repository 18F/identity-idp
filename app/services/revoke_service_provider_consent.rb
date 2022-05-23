class RevokeServiceProviderConsent
  attr_reader :identity, :now

  def initialize(identity, now: Time.zone.now)
    @identity = identity
    @now = now
  end

  def call
    identity.update!(deleted_at: now, verified_attributes: nil)
  end
end
