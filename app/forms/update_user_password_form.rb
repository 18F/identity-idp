class UpdateUserPasswordForm
  include ActiveModel::Model
  include FormPasswordValidator

  delegate :personal_key, to: :encryptor

  def initialize(user, user_session = nil)
    @user = user
    @user_session = user_session
    @validate_confirmation = true
  end

  def submit(params)
    @password = params[:password]
    @password_confirmation = params[:password_confirmation]
    success = valid?
    process_valid_submission if success
    FormResponse.new(success: success, errors: errors, extra: extra_analytics_attributes)
  end

  private

  attr_reader :user, :user_session

  def process_valid_submission
    update_user_password
    encrypt_user_profiles
  end

  def update_user_password
    attributes = { password: password }
    UpdateUser.new(user: user, attributes: attributes).call
  end

  def encrypt_user_profiles
    return if user.active_or_pending_profile.blank?

    encryptor.call
  end

  def encryptor
    @encryptor ||= UserProfilesEncryptor.new(user, user_session, password)
  end

  def extra_analytics_attributes
    {
      active_profile_present: user.active_profile.present?,
      pending_profile_present: user.pending_profile.present?,
      user_id: user.uuid,
    }
  end
end
