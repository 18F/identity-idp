module UserAuthenticator
  def authenticate_user
    authenticate_user!(force: true)
  end
end
