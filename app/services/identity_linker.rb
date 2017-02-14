class IdentityLinker
  attr_reader :user, :provider

  def initialize(user, provider)
    @user = user
    @provider = provider
  end

  def link_identity(session_uuid: nil, **extra_attrs)
    attributes = merged_attributes(session_uuid, extra_attrs)
    identity.update!(attributes)
  end

  def already_linked?
    identity_relation.exists?
  end

  private

  def identity
    @identity ||= identity_relation.first_or_create
  end

  def identity_relation
    user.identities.where(service_provider: provider)
  end

  def merged_attributes(session_uuid, extra_attrs)
    identity_attributes(session_uuid: session_uuid).merge(optional_attributes(extra_attrs))
  end

  def identity_attributes(session_uuid: nil)
    session_uuid ||= SecureRandom.uuid
    {
      last_authenticated_at: Time.zone.now,
      session_uuid: session_uuid,
      access_token: SecureRandom.urlsafe_base64,
    }
  end

  def optional_attributes(nonce: nil, ial: nil, scope: nil, code_challenge: nil)
    { nonce: nonce, ial: ial, scope: scope, code_challenge: code_challenge }
  end
end
