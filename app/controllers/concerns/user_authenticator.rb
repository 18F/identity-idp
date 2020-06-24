module UserAuthenticator
  def authenticate_user
    puts "#{'~'*10} authenticate_user"
    authenticate_user!(force: true)
  end
end
