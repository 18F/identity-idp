module UserNavigationConcern
  extend ActiveSupport::Concern

  def url_after_success
    policy = PersonalKeyForNewUserPolicy.new(user: current_user, session: session)
    return sign_up_personal_key_url if policy.show_personal_key_after_initial_2fa_setup?
    after_sign_in_path_for(current_user)
  end

  def after_otp_verification_confirmation_url
    policy = PersonalKeyForNewUserPolicy.new(user: current_user, session: session)

    if policy.show_personal_key_after_initial_2fa_setup?
      sign_up_personal_key_url
    elsif @updating_existing_number
      account_url
    elsif decorated_user.password_reset_profile.present?
      reactivate_account_url
    else
      return successful_path
    end
  end
end
