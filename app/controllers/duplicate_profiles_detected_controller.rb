# frozen_string_literal: true

class DuplicateProfilesDetectedController < ApplicationController
  before_action :confirm_two_factor_authenticated
  before_action :redirect_unless_user_has_active_duplicate_profile
  rescue_from ActionView::Template::Error, with: :handle_template_error

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
    return redirect_to(root_url) unless current_user&.identity_verified_with_facial_match?
    return redirect_to(root_url) unless duplicate_profile_set.present?
  end

  def duplicate_profile_set
    return nil unless current_user&.active_profile

    @duplicate_profile_set ||= if IdentityConfig.store.enable_one_account_global_detection
                                 DuplicateProfileSet.involving_profile_global(
                                   profile_id: current_user.active_profile.id,
                                 )
    else
      DuplicateProfileSet.involving_profile(
        profile_id: current_user.active_profile.id,
        service_provider: current_sp&.issuer,
      )
    end
  end

  def notify_users_of_duplicate_profile(source:)
    return unless duplicate_profile_set
    return if user_session[:dupe_profiles_notified]
    agency_name = current_sp&.friendly_name || current_sp&.agency&.name

    duplicate_profile_set.profile_ids.each do |profile_id|
      next if current_user&.active_profile&.id == profile_id
      profiles = Profile.where(id: profile_id)
      next unless profiles.present?
      AlertUserDuplicateProfileDiscoveredJob.perform_later(
        user: profiles.first.user,
        agency: agency_name,
        type: source,
      )
    end

    user_session[:dupe_profiles_notified] = true
  end

  def handle_template_error(exception)
    global_detection_enabled = IdentityConfig.store.enable_one_account_global_detection.to_s
    sp_name = decorated_sp_session.try(:sp_name)
    Rails.logger.error(
      "Template error in #{controller_path}##{action_name}-" \
      "#{exception.message}-" \
      "global_detection_enabled: #{global_detection_enabled}-" \
      "sp_name: #{sp_name}",
    )

    redirect_to root_url
  end
end
