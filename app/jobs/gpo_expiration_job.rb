# frozen_string_literal: true

class GpoExpirationJob < ApplicationJob
  queue_as :low

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
      end
    end
  end

  def gpo_profiles_that_should_be_expired(as_of:, min_profile_age: nil)
    possible_profile_ids = Profile
      .and(are_pending_gpo_verification)
      .and(user_cant_request_more_letters(as_of: as_of))
      .and(are_old_enough(as_of: as_of, min_profile_age: min_profile_age))
      .pluck(:id)

    Profile.where(id: profile_ids_with_expired_latest_code(possible_profile_ids, as_of: as_of))
  end

  private

  def profile_ids_with_expired_latest_code(profile_ids, as_of:)
    GpoConfirmationCode
      .where(profile_id: profile_ids)
      .select('DISTINCT ON (profile_id) *')
      .order('profile_id, code_sent_at DESC')
      .select { |gpo_confirmation_code| gpo_confirmation_code.expired?(as_of: as_of) }
      .map(&:profile_id)
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

  def user_cant_request_more_letters(as_of:)
    max_created_at = as_of - IdentityConfig.store.gpo_max_profile_age_to_send_letter_in_days.days
    Profile.where(created_at: [..max_created_at])
  end
end
