class SendGpoCodeExpirationNoticesJob < ApplicationJob
  queue_as :low

  def initialize(analytics: nil)
    @analytics = analytics
  end

  def perform
    codes_to_send_notifications_for.find_each do |code|
      user = code.profile.user

      user.send_email_to_all_addresses(:gpo_code_expired, code_sent_at: code.code_sent_at)
      code.update(expiration_notice_sent_at: Time.zone.now)

      analytics.idv_gpo_expiration_email_sent(user_id: user.uuid)
    end
  end

  def codes_to_send_notifications_for
    # We are looking at a 48 hr window in which all codes will _definitely_ be expired.
    bounds = calculate_notification_window_bounds
    expired_codes_needing_notification_sent_between(bounds)
  end

  def calculate_notification_window_bounds(as_of: Time.zone.now)
    to = as_of.beginning_of_day - IdentityConfig.store.usps_confirmation_max_days.days
    from = to - 2.days
    from..to
  end

  private

  def analytics
    @analytics ||= Analytics.new(user: AnonymousUser.new, request: nil, session: {}, sp: nil)
  end

  def expired_codes_needing_notification_sent_between(bounds)
    GpoConfirmationCode.joins(:profile).
      where(no_prior_expiration_notice_sent_for_code).
      and(code_sent_within(bounds)).
      and(profile_is_pending_gpo).
      and(profile_has_not_been_otherwise_deactivated).
      and(user_has_not_completed_idv_since_requesting_code).
      and(code_is_most_recent_one_sent_for_the_profile)
  end

  def no_prior_expiration_notice_sent_for_code
    { expiration_notice_sent_at: nil }
  end

  def code_sent_within(bounds)
    GpoConfirmationCode.where(code_sent_at: bounds)
  end

  def profile_is_pending_gpo
    GpoConfirmationCode.joins(:profile).where.not(profile: { gpo_verification_pending_at: nil })
  end

  def profile_has_not_been_otherwise_deactivated
    GpoConfirmationCode.joins(:profile).where(profile: { deactivation_reason: nil })
  end

  def user_has_not_completed_idv_since_requesting_code
    GpoConfirmationCode.joins(:profile).where.not(
      profile: {
        user_id: User.joins(:profiles).where(
          profiles: {
            active: true,
          },
        ),
      },
    )
  end

  def code_is_most_recent_one_sent_for_the_profile
    GpoConfirmationCode.where(
      code_sent_at: GpoConfirmationCode.
        select('max(code_sent_at)').
        from('usps_confirmation_codes child').
        where('child.profile_id = usps_confirmation_codes.profile_id'),
    )
  end
end
