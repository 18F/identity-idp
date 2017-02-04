module RecoveryCodeConcern
  delegate :active_profile, to: :current_user

  def create_new_code
    if active_profile.present?
      Pii::ReEncryptor.new(user: current_user, user_session: user_session).perform
      active_profile.recovery_code
    else
      RecoveryCodeGenerator.new(current_user).create
    end
  end
end
