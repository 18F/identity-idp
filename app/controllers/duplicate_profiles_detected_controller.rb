# frozen_string_literal: true

class DuplicateProfilesDetectedController < ApplicationController
  before_action :confirm_two_factor_authenticated
  before_action :redirect_unless_user_has_active_duplicate_profile_confirmation

  def show
    @dupe_profiles_detected_presenter = DuplicateProfilesDetectedPresenter.new(
      user: current_user, user_session: user_session,
    )
    analytics.one_account_duplicate_profiles_detected
  end

  def do_not_recognize_profiles
    analytics.one_account_unknown_profile_detected

    redirect_to after_sign_in_path_for(current_user)
  end

  def recognize_all_profiles
    analytics.one_account_recognize_all_profiles

    redirect_to after_sign_in_path_for(current_user)
  end

  private

  def redirect_unless_user_has_active_duplicate_profile_confirmation
    if current_user&.active_profile.present?
      if !user_session[:duplicate_profile_id].nil?
        return
      end
    end
    redirect_to root_url
  end
end
