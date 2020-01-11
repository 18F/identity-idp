class IdentityLinker
  attr_reader :user, :provider

  def initialize(user, provider)
    @user = user
    @provider = provider
  end

  def link_identity(**extra_attrs)
    attributes = merged_attributes(extra_attrs)
    identity.update!(attributes)
    AgencyIdentityLinker.new(identity).link_identity
    identity
  end

  def already_linked?
    identity_relation.exists?
  end

  private

  def identity
    @identity ||= find_or_create_identity_with_costing
  end

  def find_or_create_identity_with_costing
    identity_record = identity_relation.first
    return identity_record if identity_record
    Db::SpCost::AddSpCost.call(provider, :user_added)
    user.identities.create(service_provider: provider)
  end

  def identity_relation
    user.identities.where(service_provider: provider)
  end

  def merged_attributes(extra_attrs)
    identity_attributes.merge(optional_attributes(extra_attrs))
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
    verified_attributes: nil
  )
    {
      code_challenge: code_challenge,
      ial: ial,
      nonce: nonce,
      rails_session_id: rails_session_id,
      scope: scope,
      verified_attributes: merge_attributes(verified_attributes),
    }
  end

  def merge_attributes(verified_attributes)
    verified_attributes = verified_attributes.to_a.map(&:to_s)
    (identity.verified_attributes.to_a + verified_attributes).uniq.sort
  end
end
