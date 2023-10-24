class SendGpoCodeExpirationNoticesJob < ApplicationJob
  queue_as :low

  def initialize(analytics: nil)
    @analytics = analytics
  end

  def perform
    raise 'Not implemented'
  end

  def codes_to_send_notifications_for
    latest_time = Time.zone.now - IdentityConfig.store.usps_confirmation_max_days.days
    earliest_time = latest_time - 1.day

    expired_codes_needing_notification_sent_between(
      from: earliest_time,
      to: latest_time,
    )
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
      where(profile: { deactivation_reason: nil }).or(
        GpoConfirmationCode.where.not(
          profile: {
            deactivation_reason: [
              :password_reset,
              :encryption_error,
              :verification_cancelled,
            ],
          },
        ),
      ).

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
