IdentityLinker = Struct.new(:user, :provider, :authn_context) do
  attr_reader :identity

  def link_identity
    find_or_create_identity

    identity.update(identity_attributes)
  end

  private

  def find_or_create_identity
    @identity = Identity.find_or_create_by(
      service_provider: provider,
      user_id: user.id
    )
  end

  def identity_attributes
    {
      authn_context: authn_context,
      session_index: session_index,
      last_authenticated_at: Time.current,
      session_uuid: "_#{SecureRandom.uuid}"
    }
  end

  def session_index
    user.active_identities.size + 1
  end
end
