#TODO clara rename this?
module UserNavigationConcern
  extend ActiveSupport::Concern


  #TODO clara rename this?
  def url_after_success
    policy = PersonalKeyForNewUserPolicy.new(user: current_user, session: session)
    binding.pry
    return sign_up_personal_key_url if policy.show_personal_key_after_initial_2fa_setup?
    binding.pry
    successful_path

    #TODO clara we should have a specific call out that directs users to the idv views vs be the default
    #idv_jurisdiction_url
  end

  def after_otp_verification_confirmation_url
    policy = PersonalKeyForNewUserPolicy.new(user: current_user, session: session)

    if decorated_user.password_reset_profile.present? ||
      @updating_existing_number ||
      policy.show_personal_key_after_initial_2fa_setup?
      after_otp_action_url
    else
      after_sign_in_path_for(current_user)
    end
  end

  def after_otp_action_url
    policy = PersonalKeyForNewUserPolicy.new(user: current_user, session: session)

    if policy.show_personal_key_after_initial_2fa_setup?
      sign_up_personal_key_url
    elsif @updating_existing_number
      account_url
    elsif decorated_user.password_reset_profile.present?
      reactivate_account_url
    else
      account_url
    end
  end

  def successful_path
    binding.pry
    return two_factor_options_url unless MfaPolicy.new(user: current_user).auth_methods_satisfied?
    binding.pry
    after_sign_in_path_for(current_user)
  end

  def user_already_has_a_personal_key?
    TwoFactorAuthentication::PersonalKeyPolicy.new(current_user).configured?
  end
end