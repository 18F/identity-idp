class GpoExpirationJob < ApplicationJob
  queue_as :low

  def initialize(analytics: nil, on_profile_expired: nil)
    @analytics = analytics
    @on_profile_expired = on_profile_expired
  end

  def perform(
    dry_run: false,
    limit: nil,
    min_profile_age: nil,
    now: Time.zone.now,
    statement_timeout: 10.minutes
  )
    profiles = gpo_profiles_that_should_be_expired(as_of: now, min_profile_age: min_profile_age)

    if limit.present?
      profiles = profiles.limit(limit)
    end

    with_statement_timeout(statement_timeout) do
      profiles.find_each do |profile|
        gpo_verification_pending_at = profile.gpo_verification_pending_at

        if gpo_verification_pending_at.blank?
          raise "Profile #{profile.id} does not have gpo_verification_pending_at"
        end

        expire_profile(profile: profile) unless dry_run

        on_profile_expired&.call(
          profile: profile,
          gpo_verification_pending_at: gpo_verification_pending_at,
        )
      end
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

  attr_reader :on_profile_expired

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

  def with_statement_timeout(timeout)
    ActiveRecord::Base.transaction do
      quoted_timeout = ActiveRecord::Base.connection.quote("#{timeout.seconds}s")
      ActiveRecord::Base.connection.execute(
        "SET LOCAL statement_timeout = #{quoted_timeout}",
      )
      yield
    end
  end

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
