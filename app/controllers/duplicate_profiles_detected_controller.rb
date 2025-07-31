# frozen_string_literal: true

class DuplicateProfilesDetectedController < ApplicationController
  before_action :confirm_two_factor_authenticated
  before_action :redirect_unless_user_has_active_duplicate_profile_confirmation

  def show
    @dupe_profiles_detected_presenter = DuplicateProfilesDetectedPresenter.new(
      user: current_user, user_session: user_session,
    )
    notify_users_of_duplicate_profile_sign_in
    analytics.one_account_duplicate_profiles_detected
  end

  def do_not_recognize_profiles
    analytics.one_account_unknown_profile_detected

    user_session.delete(:duplicate_profile_ids)

    redirect_to after_sign_in_path_for(current_user)
  end

  def recognize_all_profiles
    analytics.one_account_recognize_all_profiles

    user_session.delete(:duplicate_profile_ids)
    redirect_to after_sign_in_path_for(current_user)
  end

  private

  def redirect_unless_user_has_active_duplicate_profile_confirmation
    if current_user&.active_profile.present?
      if user_session[:duplicate_profile_ids].present?
        return
      end
    end
    redirect_to root_url
  end

  def notify_users_of_duplicate_profile_sign_in
    return unless user_session[:duplicate_profile_ids].present?
    return if user_session[:dupe_profiles_notified]
    agency_name = current_sp.friendly_name || current_sp.agency&.name

    user_session[:duplicate_profile_ids].each do |profile_id|
      profile = Profile.find(profile_id)
      AlertUserDuplicateProfileDiscoveredJob.perform_later(
        user: profile.user,
        agency: agency_name,
        type: AlertUserDuplicateProfileDiscoveredJob::SIGN_IN_ATTEMPTED,
      )
    end

    user_session[:dupe_profiles_notified] = true
  end
end
