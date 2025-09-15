# frozen_string_literal: true

module OneAccountConcern
  extend ActiveSupport::Concern

  def log_one_account_self_service_if_applicable(source:)
    return unless current_user&.active_profile&.facial_match?
    sets = DuplicateProfileSet
      .duplicate_profile_set_for_profile(profile_id: current_user.active_profile.id)
    return if sets.blank?

    sets.each do |set|
      analytics.one_account_self_service(
        source: source,
        service_provider: set.service_provider,
        associated_profiles_count: set.profile_ids.count - 1,
        dupe_profile_set_id: set.id,
      )
    end
  end
end
