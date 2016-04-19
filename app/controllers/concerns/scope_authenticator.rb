module ScopeAuthenticator
  # Authenticates the current scope and gets the current resource from
  # the session.
  def authenticate_scope!
    send(:"authenticate_#{resource_name}!", force: true)
    self.resource = send(:"current_#{resource_name}")
  end
end
