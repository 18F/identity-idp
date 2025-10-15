# frozen_string_literal: true

class DuplicateProfilesDetectedController < ApplicationController
  before_action :confirm_two_factor_authenticated
  before_action :redirect_unless_user_has_active_duplicate_profile

  def show
    @dupe_profiles_detected_presenter = DuplicateProfilesDetectedPresenter.new(
      user: current_user,
      duplicate_profile_set: duplicate_profile_set,
    )
    notify_users_of_duplicate_profile(source: params[:source]&.to_sym)
    analytics.one_account_duplicate_profiles_warning_page_visited(source: params[:source]&.to_sym)
  end

  private

  def redirect_unless_user_has_active_duplicate_profile
    if current_user&.active_profile.present?
      if duplicate_profile_set.present?
        return
      end
    end
    redirect_to root_url
  end

  def duplicate_profile_set
    @duplicate_profile_set ||= DuplicateProfileSet.involving_profile(
      profile_id: current_user.active_profile.id,
      service_provider: current_sp&.issuer,
    )
  end

  def notify_users_of_duplicate_profile(source:)
    return unless duplicate_profile_set
    return if user_session[:dupe_profiles_notified]
    agency_name = current_sp.friendly_name || current_sp.agency&.name

    duplicate_profile_set.profile_ids.each do |profile_id|
      next if current_user&.active_profile&.id == profile_id
      profiles = Profile.where(id: profile_id)
      next unless profiles.present
      AlertUserDuplicateProfileDiscoveredJob.perform_later(
        user: profiles.first.user,
        agency: agency_name,
        type: source,
      )
    end

    user_session[:dupe_profiles_notified] = true
  end
end
