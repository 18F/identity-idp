IdentityDecorator = Struct.new(:identity) do
  def pretty_event_type
    I18n.t('event_types.authenticated_at', service_provider: identity.display_name)
  end

  def happened_at
    identity.last_authenticated_at
  end

  def session_for(session_id)
    identity.sessions.find_by(session_id: session_id) || Session.new
  end
end
