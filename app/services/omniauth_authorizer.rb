OmniauthAuthorizer = Struct.new(:auth_hash, :session) do
  attr_reader :auth

  def perform
    find_or_create_auth

    unless auth.valid?
      return yield auth.user, :process_invalid_authorization if block_given?
    end

    update_auth
    update_session

    yield auth.user, :process_valid_authorization if block_given?
  end

  private

  def find_or_create_auth
    @auth = find_from_hash || create_from_hash
  end

  def find_from_hash
    Authorization.find_by_provider_and_uid(
      auth_hash.provider, auth_hash.extra.raw_info['uuid']
    )
  end

  def create_from_hash
    user = CreateOmniauthUser.new(auth_hash.extra.raw_info['email']).perform

    Authorization.create(
      user: user,
      uid: auth_hash.extra.raw_info['uuid'],
      provider: auth_hash.provider
    )
  end

  def update_auth
    auth.update(authorized_at: Time.current)
  end

  def update_session
    session[:omniauthed] = true
  end
end
