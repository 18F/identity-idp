# frozen_string_literal: true

class DuplicateProfilesDetectedController < ApplicationController
  before_action :confirm_two_factor_authenticated
  before_action :redirect_unless_user_has_active_duplicate_profile_confirmation

  def show
    @dupe_profiles_detected_presenter = DuplicateProfilesDetectedPresenter.new(user: current_user)
    analytics.one_account_duplicate_profiles_detected
  end

  def do_not_recognize_profiles
    analytics.one_account_unknown_profile_detected
    dupe_profile_confirmation.mark_some_profiles_not_recognized
    redirect_to after_sign_in_path_for(current_user)
  end

  def recognize_all_profiles
    analytics.one_account_recognize_all_profiles
    dupe_profile_confirmation.mark_all_profiles_recognized
    redirect_to after_sign_in_path_for(current_user)
  end

  private

  def redirect_unless_user_has_active_duplicate_profile_confirmation
    if current_user&.active_profile.present?
      if dupe_profile_confirmation && dupe_profile_confirmation&.confirmed_all.nil?
        return
      end
    end
    redirect_to root_url
  end

  def dupe_profile_confirmation
    return unless current_user.active_profile
    @dupe_profile_confirmation ||= DuplicateProfileConfirmation.find_by(
      profile_id: current_user.active_profile.id,
    )
  end
end
