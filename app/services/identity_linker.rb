IdentityLinker = Struct.new(:user, :provider, :session_id) do
  def link_identity
    find_or_create_identity
  end

  private

  attr_reader :identity, :session

  def find_or_create_identity
    Identity.transaction do
      @identity = Identity.find_or_create_by!(
        service_provider: provider,
        user_id: user.id
      )
      identity.update!(last_authenticated_at: Time.current)
      find_or_create_session
    end
  end

  def find_or_create_session
    @session = Session.find_or_create_by!(
      identity_id: identity.id,
      session_id: session_id
    )
  end
end
