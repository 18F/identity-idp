class UserProfilesEncryptor
  attr_reader :personal_key

  def initialize(user, user_session, password)
    @user = user
    @user_session = user_session
    @password = password
  end

  def call
    if user.active_profile.present?
      encrypt_pii_for_profile(user.active_profile)
    end
    if user.pending_profile.present?
      encrypt_pii_for_profile(user.pending_profile)
    end
  end

  private

  attr_reader :user, :password, :user_session

  def encrypt_pii_for_profile(profile)
    pii = Pii::Cacher.new(user, user_session).fetch(profile.id)
    @personal_key = profile.encrypt_pii(pii, password)
    profile.save!
  end
end
