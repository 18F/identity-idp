class IdentityLinker
  attr_reader :user, :service_provider

  def initialize(user, service_provider)
    @user = user
    @service_provider = service_provider
    @ial = nil
  end

  def link_identity(**extra_attrs)
    return unless user && service_provider.present?
    process_ial(extra_attrs)
    attributes = merged_attributes(extra_attrs)
    identity.update!(attributes)
    AgencyIdentityLinker.new(identity).link_identity
    identity
  end

  private

  def process_ial(extra_attrs)
    @ial = extra_attrs[:ial]
    now = Time.zone.now
    process_ial_at(now)
    process_verified_at(now)
  end

  def process_ial_at(now)
    if @ial == Idp::Constants::IAL2 || (identity.verified_at.present? && @ial&.zero?)
      identity.last_ial2_authenticated_at = now
    else
      identity.last_ial1_authenticated_at = now
    end
  end

  def process_verified_at(now)
    return unless @ial == Idp::Constants::IAL2 && identity.verified_at.nil?
    identity.verified_at = now
  end

  def identity
    @identity ||= find_or_create_identity
  end

  # mattw: Leaving this as-is for this PR.
  def find_or_create_identity
    user.identities.create_or_find_by(service_provider: service_provider.issuer)
  end

  def merged_attributes(extra_attrs)
    identity_attributes.merge(optional_attributes(**extra_attrs))
  end

  def identity_attributes
    {
      last_authenticated_at: Time.zone.now,
      session_uuid: SecureRandom.uuid,
      access_token: SecureRandom.urlsafe_base64,
    }
  end

  def optional_attributes(
    code_challenge: nil,
    ial: nil,
    nonce: nil,
    rails_session_id: nil,
    scope: nil,
    verified_attributes: nil,
    last_consented_at: nil,
    clear_deleted_at: nil
  )
    {
      code_challenge: code_challenge,
      ial: ial,
      nonce: nonce,
      rails_session_id: rails_session_id,
      scope: scope,
      verified_attributes: merge_attributes(verified_attributes),
    }.tap do |hash|
      hash[:last_consented_at] = last_consented_at if last_consented_at
      hash[:deleted_at] = nil if clear_deleted_at
    end
  end

  def merge_attributes(verified_attributes)
    verified_attributes = verified_attributes.to_a.map(&:to_s)
    (identity.verified_attributes.to_a + verified_attributes).uniq.sort
  end
end
