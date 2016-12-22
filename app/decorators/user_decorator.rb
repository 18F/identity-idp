include ActionView::Helpers::DateHelper

UserDecorator = Struct.new(:user) do
  MAX_RECENT_EVENTS = 5

  def lockout_time_remaining
    (Devise.direct_otp_valid_for - (Time.zone.now - user.second_factor_locked_at)).to_i
  end

  def lockout_time_remaining_in_words
    current_time = Time.zone.now

    distance_of_time_in_words(
      current_time, current_time + lockout_time_remaining, true, highest_measures: 2
    )
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

  def may_bypass_2fa?(session = {})
    omniauthed?(session)
  end

  def masked_two_factor_phone_number
    masked_number(user.phone)
  end

  def identity_verified?
    user.active_profile.present?
  end

  def identity_not_verified?
    !identity_verified?
  end

  def active_identity_for(service_provider)
    user.active_identities.find_by(service_provider: service_provider.issuer)
  end

  def qrcode(otp_secret_key)
    options = {
      issuer: 'Login.gov',
      otp_secret_key: otp_secret_key
    }
    url = user.provisioning_uri(nil, options)
    qrcode = RQRCode::QRCode.new(url)
    qrcode.as_png(size: 280).to_data_url
  end

  def blocked_from_entering_2fa_code?
    user.second_factor_locked_at.present? && !blocked_from_2fa_period_expired?
  end

  def no_longer_blocked_from_entering_2fa_code?
    user.second_factor_locked_at.present? && blocked_from_2fa_period_expired?
  end

  def should_acknowledge_recovery_code?(session)
    user.recovery_code.blank? && !omniauthed?(session)
  end

  def recent_events
    events = user.events.order('updated_at DESC').limit(MAX_RECENT_EVENTS).map(&:decorate)
    identities = user.identities.order('last_authenticated_at DESC').map(&:decorate)
    (events + identities).sort { |thing_a, thing_b| thing_b.happened_at <=> thing_a.happened_at }
  end

  def verified_account_partial
    if identity_verified?
      'profile/verified_account_badge'
    else
      'shared/null'
    end
  end

  def basic_account_partial
    if identity_not_verified?
      'profile/basic_account_badge'
    else
      'shared/null'
    end
  end

  private

  def omniauthed?(session)
    return false if session[:omniauthed] != true

    session.delete(:omniauthed)
  end

  def masked_number(number)
    "***-***-#{number[-4..-1]}"
  end

  def blocked_from_2fa_period_expired?
    (Time.current - user.second_factor_locked_at) > Devise.direct_otp_valid_for
  end
end
