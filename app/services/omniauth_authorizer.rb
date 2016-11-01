OmniauthAuthorizer = Struct.new(:auth_hash, :session) do
  attr_reader :auth

  def perform
    find_or_create_auth

    unless auth.valid?
      yield auth_user, :process_invalid_authorization if block_given?
      return
    end

    update_auth
    update_session

    yield auth_user, :process_valid_authorization if block_given?
  end

  private

  def find_or_create_auth
    @auth ||= find_from_hash || create_from_hash
  end

  def find_from_hash
    Authorization.find_by(
      provider: auth_hash.provider, uid: auth_hash.extra.raw_info['uuid']
    )
  end

  def create_from_hash
    extra_attributes = auth_hash.extra.raw_info

    user = CreateOmniauthUser.new(extra_attributes['email']).perform

    Authorization.create(
      user: user,
      uid: extra_attributes['uuid'],
      provider: auth_hash.provider
    )
  end

  def update_auth
    auth.update(authorized_at: Time.current)
  end

  def update_session
    session[:omniauthed] = true
  end

  def auth_user
    auth.user
  end
end
