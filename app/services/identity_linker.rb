IdentityLinker = Struct.new(:user, :authenticated, :sp_data) do
  def set_active_identity
    active_identity
  end

  def update_user_and_identity_if_ial_token
    return if sp_data[:ial_token].blank?

    update_user
    update_active_identity
  end

  private

  def update_user
    user.update(ial_token: sp_data[:ial_token])
  end

  def update_active_identity
    active_identity.update(quiz_started: true) if user.reload.ial_token
  end

  def active_identity
    @active_identity ||= user.set_active_identity(
      sp_data[:provider], sp_data[:authn_context], authenticated
    )
  end
end
