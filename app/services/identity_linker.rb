IdentityLinker = Struct.new(:user, :provider) do
  attr_reader :identity

  def link_identity(nonce: nil, session_uuid: nil, ial: nil)
    find_or_create_identity

    identity.update!(identity_attributes(nonce: nonce, session_uuid: session_uuid, ial: ial))
  end

  private

  def find_or_create_identity
    @identity = Identity.find_or_create_by(
      service_provider: provider,
      user_id: user.id
    )
  end

  def identity_attributes(nonce: nil, session_uuid: nil, ial: nil)
    session_uuid ||= SecureRandom.uuid
    {
      last_authenticated_at: Time.current,
      session_uuid: session_uuid,
      nonce: nonce,
      ial: ial,
      access_token: SecureRandom.urlsafe_base64
    }
  end
end
