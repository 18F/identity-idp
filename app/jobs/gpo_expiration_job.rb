class GpoExpirationJob < ApplicationJob
  queue_as :low

  def initialize(analytics: nil)
    @analytics = analytics
  end

  def expire_profile(profile:)
    gpo_verification_pending_at = profile.gpo_verification_pending_at

    profile.deactivate_due_to_gpo_expiration

    analytics.idv_gpo_expired(
      user_id: profile.user.uuid,
      user_has_active_profile: profile.user.active_profile.present?,
      letters_sent: profile.gpo_confirmation_codes.count,
      gpo_verification_pending_at: gpo_verification_pending_at,
    )
  end

  def perform(now: Time.zone.now, limit: nil, min_profile_age: nil)
    profiles = gpo_profiles_that_should_be_expired(as_of: now, min_profile_age: min_profile_age)

    if limit.present?
      profiles = profiles.limit(limit)
    end

    profiles.find_each do |profile|
      expire_profile(profile: profile)
    end
  end

  def gpo_profiles_that_should_be_expired(as_of:, min_profile_age: nil)
    Profile.
      and(are_pending_gpo_verification).
      and(user_cant_request_more_letters(as_of: as_of)).
      and(most_recent_code_has_expired(as_of: as_of)).
      and(are_old_enough(as_of: as_of, min_profile_age: min_profile_age))
  end

  private

  def analytics
    @analytics ||= Analytics.new(user: AnonymousUser.new, request: nil, session: {}, sp: nil)
  end

  def are_old_enough(as_of:, min_profile_age:)
    return Profile.all if min_profile_age.blank?

    max_created_at = as_of - min_profile_age

    return Profile.where(created_at: ..max_created_at)
  end

  def are_pending_gpo_verification
    Profile.where.not(gpo_verification_pending_at: nil)
  end

  def most_recent_code_has_expired(as_of:)
    # Any Profile where the most recent code was sent *before*
    # usps_confirmation_max_days days ago is now expired
    max_code_sent_at = as_of - IdentityConfig.store.usps_confirmation_max_days.days

    Profile.where(
      id: GpoConfirmationCode.
        select(:profile_id).
        group(:profile_id).
        having('max(code_sent_at) < ?', max_code_sent_at),
    )
  end

  def user_cant_request_more_letters(as_of:)
    max_created_at = as_of - IdentityConfig.store.gpo_max_profile_age_to_send_letter_in_days.days
    Profile.where(created_at: [..max_created_at])
  end
end
