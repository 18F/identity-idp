class UserDecorator
  include ActionView::Helpers::DateHelper

  attr_reader :user

  MAX_RECENT_EVENTS = 5
  DEFAULT_LOCKOUT_PERIOD = 10.minutes

  def initialize(user)
    @user = user
  end

  def email
    user.email_address&.email
  end

  def lockout_time_remaining_in_words
    current_time = Time.zone.now

    distance_of_time_in_words(
      current_time, current_time + lockout_time_remaining, true, highest_measures: 2
    )
  end

  def lockout_time_remaining
    (lockout_period - (Time.zone.now - user.second_factor_locked_at)).to_i
  end

  def confirmation_period_expired_error
    I18n.t('errors.messages.confirmation_period_expired', period: confirmation_period)
  end

  def confirmation_period
    current_time = Time.zone.now

    distance_of_time_in_words(
      current_time, current_time + Devise.confirm_within, true, accumulate_on: :hours
    )
  end

  def masked_two_factor_phone_number
    masked_number(MfaContext.new(user).phone_configurations.first&.phone)
  end

  def active_identity_for(service_provider)
    user.active_identities.find_by(service_provider: service_provider.issuer)
  end

  def active_or_pending_profile
    user.active_profile || pending_profile
  end

  def pending_profile_requires_verification?
    return false if pending_profile.blank?
    return true if identity_not_verified?
    return false if active_profile_newer_than_pending_profile?
    true
  end

  def pending_profile?
    pending_profile.present?
  end

  def pending_profile
    user.profiles.verification_pending.order(created_at: :desc).first
  end

  def identity_not_verified?
    !identity_verified?
  end

  def identity_verified?
    user.active_profile.present?
  end

  def active_profile_newer_than_pending_profile?
    user.active_profile.activated_at >= pending_profile.created_at
  end

  # This user's most recently activated profile that has also been deactivated
  # due to a password reset, or nil if there is no such profile
  def password_reset_profile
    profile = user.profiles.order(activated_at: :desc).first
    profile if profile&.password_reset?
  end

  def qrcode(otp_secret_key)
    options = {
      issuer: 'Login.gov',
      otp_secret_key: otp_secret_key,
    }
    url = user.provisioning_uri(nil, options)
    qrcode = RQRCode::QRCode.new(url)
    qrcode.as_png(size: 280).to_data_url
  end

  def locked_out?
    user.second_factor_locked_at.present? && !lockout_period_expired?
  end

  def no_longer_locked_out?
    user.second_factor_locked_at.present? && lockout_period_expired?
  end

  def recent_events
    events = user.events.order('created_at DESC').limit(MAX_RECENT_EVENTS).map(&:decorate)
    identities = user.identities.order('last_authenticated_at DESC').map(&:decorate)
    (events + identities).sort_by(&:happened_at).reverse
  end

  def connected_apps
    user.identities.order('created_at DESC').map(&:decorate)
  end

  def verified_account_partial
    if identity_verified?
      'accounts/verified_account_badge'
    else
      'shared/null'
    end
  end

  def delete_account_bullet_key
    if identity_verified?
      I18n.t('users.delete.bullet_2_loa3', app: APP_NAME)
    else
      I18n.t('users.delete.bullet_2_loa1', app: APP_NAME)
    end
  end

  private

  def masked_number(number)
    return '' if number.blank?
    "***-***-#{number[-4..-1]}"
  end

  def lockout_period
    return DEFAULT_LOCKOUT_PERIOD if lockout_period_config.blank?
    lockout_period_config.to_i.minutes
  end

  def lockout_period_config
    @config ||= Figaro.env.lockout_period_in_minutes
  end

  def lockout_period_expired?
    (Time.zone.now - user.second_factor_locked_at) > lockout_period
  end
end
