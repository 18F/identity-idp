class UserDecorator
  include ActionView::Helpers::DateHelper

  attr_reader :user

  MAX_RECENT_EVENTS = 5
  MAX_RECENT_DEVICES = 5
  DEFAULT_LOCKOUT_PERIOD = 10.minutes

  def initialize(user)
    @user = user
  end

  def email
    user.email_addresses.take&.email
  end

  def email_language_preference_description
    if I18n.locale_available?(user.email_language)
      # i18n-tasks-use t('account.email_language.name.en')
      # i18n-tasks-use t('account.email_language.name.es')
      # i18n-tasks-use t('account.email_language.name.fr')
      I18n.t("account.email_language.name.#{user.email_language}")
    else
      I18n.t('account.email_language.name.en')
    end
  end

  def visible_email_addresses
    user.email_addresses.filter do |email_address|
      email_address.confirmed? || !email_address.confirmation_period_expired?
    end
  end

  def lockout_time_remaining_in_words
    current_time = Time.zone.now

    distance_of_time_in_words(
      current_time,
      current_time + lockout_time_remaining,
      true,
      highest_measures: 2,
      two_words_connector: " #{I18n.t('datetime.dotiw.two_words_connector')} ",
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
      current_time,
      current_time + Devise.confirm_within,
      true,
      accumulate_on: :hours,
      two_words_connector: " #{I18n.t('datetime.dotiw.two_words_connector')} ",
    )
  end

  def masked_two_factor_phone_number
    masked_number(MfaContext.new(user).phone_configurations.take&.phone)
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

  def gpo_mail_bounced?
    return unless pending_profile
    pending_profile&.gpo_confirmation_codes&.order(created_at: :desc)&.first&.bounced_at
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
      digits: TwoFactorAuthenticatable::DIRECT_OTP_LENGTH,
    }
    url = ROTP::TOTP.new(otp_secret_key, options).provisioning_uri(email)
    qrcode = RQRCode::QRCode.new(url)
    qrcode.as_png(size: 240).to_data_url
  end

  def locked_out?
    user.second_factor_locked_at.present? && !lockout_period_expired?
  end

  def no_longer_locked_out?
    user.second_factor_locked_at.present? && lockout_period_expired?
  end

  def recent_events
    events = Event.where(user_id: user.id).order('created_at DESC').limit(MAX_RECENT_EVENTS).
             map(&:decorate)
    (events + identity_events).sort_by(&:happened_at).reverse
  end

  def identity_events
    user.identities.includes(:service_provider_record).order('last_authenticated_at DESC')
  end

  def recent_devices
    DeviceTracking::ListDevices.call(user.id, 0, MAX_RECENT_DEVICES).map(&:decorate)
  end

  def devices?
    !recent_devices.empty?
  end

  def connected_apps
    user.identities.not_deleted.includes(:service_provider_record).order('created_at DESC')
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
    lockout_period_config.minutes
  end

  def lockout_period_config
    @config ||= IdentityConfig.store.lockout_period_in_minutes
  end

  def lockout_period_expired?
    (Time.zone.now - user.second_factor_locked_at) > lockout_period
  end
end
