IdentityLinker = Struct.new(:user, :provider) do
  attr_reader :identity

  def link_identity(session_uuid: nil, **extra_attrs)
    attributes = merged_attributes(session_uuid, extra_attrs)
    identity.update!(attributes)
  end

  private

  def identity
    @identity ||= Identity.find_or_create_by(
      service_provider: provider, user_id: user.id
    )
  end

  def merged_attributes(session_uuid, extra_attrs)
    identity_attributes(session_uuid: session_uuid).merge(optional_attributes(extra_attrs))
  end

  def identity_attributes(session_uuid: nil)
    session_uuid ||= SecureRandom.uuid
    {
      last_authenticated_at: Time.current,
      session_uuid: session_uuid,
      access_token: SecureRandom.urlsafe_base64
    }
  end

  def optional_attributes(nonce: nil, ial: nil, scope: nil, code_challenge: nil)
    { nonce: nonce, ial: ial, scope: scope, code_challenge: code_challenge }
  end
end
