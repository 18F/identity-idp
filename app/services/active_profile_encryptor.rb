class ActiveProfileEncryptor
  attr_reader :personal_key

  def initialize(user, user_session, password)
    @user = user
    @user_session = user_session
    @password = password
  end

  def call
    active_profile = @user.active_profile
    @personal_key = active_profile.encrypt_pii(current_pii, @password)
    active_profile.save!
  end

  private

  def current_pii
    cacher = Pii::Cacher.new(@user, @user_session)
    cacher.fetch
  end
end
