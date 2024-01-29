class UserProfilesEncryptor
  attr_reader :personal_key

  def initialize(user:, user_session:, password:)
    @user = user
    @user_session = user_session
    @password = password
  end

  def encrypt
    pii_cache = Pii::Cacher.new(user, user_session)

    if user.active_profile.present?
      pii = pii_cache.fetch(user.active_profile.id)
      encrypt_pii_for_profile(user.active_profile, pii)
    end

    if user.pending_profile.present?
      pii = pii_cache.fetch(user.pending_profile.id)
      if pii
        encrypt_pii_for_profile(user.pending_profile, pii)
      else
        user.pending_profile.deactivate(:encryption_error)
      end
    end
  end

  private

  attr_reader :user, :password, :user_session

  def encrypt_pii_for_profile(profile, pii)
    @personal_key = profile.encrypt_pii(pii, password)
    profile.save!
  end
end
