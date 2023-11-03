class GpoExpirationJob < ApplicationJob
  queue_as :low

  def initialize(analytics: nil)
    @analytics = analytics
  end

  def perform(as_of: Time.zone.now)
    profiles = gpo_profiles_that_should_be_expired(as_of: as_of)

    profiles.find_each do |profile|
      profile.deactivate_due_to_gpo_expiration

      analytics.idv_gpo_expired(
        user_id: profile.user.uuid,
        user_has_active_profile: profile.user.active_profile.present?,
        letters_sent: profile.gpo_confirmation_codes.count,
      )
    end
  end

  def gpo_profiles_that_should_be_expired(as_of:)
    Profile.
      and(are_pending_gpo_verification).
      and(user_cant_request_more_letters(as_of: as_of)).
      and(most_recent_code_has_expired(as_of: as_of))
  end

  private

  def analytics
    @analytics ||= Analytics.new(user: AnonymousUser.new, request: nil, session: {}, sp: nil)
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
