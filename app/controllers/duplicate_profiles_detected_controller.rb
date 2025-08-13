# frozen_string_literal: true

class DuplicateProfilesDetectedController < ApplicationController
  before_action :confirm_two_factor_authenticated
  before_action :redirect_unless_user_has_active_duplicate_profile_confirmation

  def show
    @dupe_profiles_detected_presenter = DuplicateProfilesDetectedPresenter.new(
      user: current_user,
      duplicate_profile: dupe_profile,
    )
    notify_users_of_duplicate_profile_sign_in
    analytics.one_account_duplicate_profiles_detected
  end

  private

  def redirect_unless_user_has_active_duplicate_profile_confirmation
    if current_user&.active_profile.present?
      if dupe_profile.present?
        return
      end
    end
    redirect_to root_url
  end

  def dupe_profile
    @dupe_profile ||= DuplicateProfile.involving_profile(
      profile_id: current_user.active_profile.id,
      service_provider: current_sp&.issuer,
    )
  end

  def notify_users_of_duplicate_profile_sign_in
    return unless dupe_profile.present?
    return if user_session[:dupe_profiles_notified]
    agency_name = current_sp.friendly_name || current_sp.agency&.name

    dupe_profile.profile_ids.each do |profile_id|
      next if current_user.active_profile.id == profile.id
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
