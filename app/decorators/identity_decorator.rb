IdentityDecorator = Struct.new(:identity) do
  delegate :display_name, to: :identity

  def event_partial
    'accounts/identity_item'
  end

  def return_to_sp_url
    identity.sp_metadata[:return_to_sp_url]
  end

  def happened_at
    EasternTimePresenter.new(identity.last_authenticated_at).to_s
  end
end
