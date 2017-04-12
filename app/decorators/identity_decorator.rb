IdentityDecorator = Struct.new(:identity) do
  def pretty_event_type
    I18n.t('event_types.authenticated_at', service_provider: identity.display_name)
  end

  def happened_at
    EasternTimePresenter.new(identity.last_authenticated_at).to_s
  end
end
