class SendGpoCodeExpirationNoticesJob < ApplicationJob
  queue_as :low

  def initialize(analytics: nil)
    @analytics = analytics
  end

  def perform
    codes_to_send_notifications_for.find_each do |code|
      user = code.profile.user

      user.send_email_to_all_addresses(:gpo_code_expired)
      code.update(expiration_notice_sent_at: Time.zone.now)

      analytics.idv_gpo_expiration_email_sent(user_id: user.uuid)
    end
  end

  def codes_to_send_notifications_for
    # We are looking at a 48 hr window in which all codes will _definitely_ be expired.
    from, to = calculate_notification_window_bounds
    expired_codes_needing_notification_sent_between(
      from: from,
      to: to,
    )
  end

  def calculate_notification_window_bounds(as_of: Time.zone.now)
    to = as_of.beginning_of_day - IdentityConfig.store.usps_confirmation_max_days.days
    from = to - 2.days
    [from, to]
  end

  private

  def analytics
    @analytics ||= Analytics.new(user: AnonymousUser.new, request: nil, session: {}, sp: nil)
  end

  def expired_codes_needing_notification_sent_between(
    from:,
    to:
  )
    GpoConfirmationCode.joins(:profile).
      # 1. Exclude codes that we've already sent an expiration notice for
      where(expiration_notice_sent_at: nil).

      # 2. Exclude codes not sent in the window we're looking at
      where(code_sent_at: from...to).

      # 3. Exclude codes where the associated profile does not have the GPO pending timestamp set
      #    (meaning they either completed GPO or reset their password).
      where.not(profile: { gpo_verification_pending_at: nil }).

      # 4. Exclude codes where the associated profile has been deactivated for some reason
      where(profile: { deactivation_reason: nil }).

      # 5. Exclude codes where the user has since gotten an active profile (no point in notifying)
      where.not(
        profile: {
          user_id: User.joins(:profiles).where(
            profiles: {
              active: true,
            },
          ),
        },
      ).

      # 6. Only include codes that are the most recent code sent for the profile
      where(
        code_sent_at: GpoConfirmationCode.
          select('max(code_sent_at)').
          from('usps_confirmation_codes child').
          where('child.profile_id = usps_confirmation_codes.profile_id'),
      )
  end
end
