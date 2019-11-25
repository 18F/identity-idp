class AddPhoneOtpVerificationForm
  attr_reader :user, :phone_confirmation_session

  def initialize(user:, phone_confirmation_session:)
    @user = user
    @phone_confirmation_session = phone_confirmation_session
  end

  def submit(code:)
    @code = code
    success = code_valid?
    if success
      clear_second_factor_attempts
      create_phone_configuration
    else
      increment_second_factor_attempts
    end
    FormResponse.new(success: success, errors: {}, extra: extra_analytics_attributes)
  end

  delegate :phone, :delivery_method, :default_phone, to: :phone_confirmation_session

  private

  attr_reader :code

  def code_valid?
    return false if phone_confirmation_session.expired?
    phone_confirmation_session.matches_code?(code)
  end

  def clear_second_factor_attempts
    UpdateUser.new(user: user, attributes: { second_factor_attempts_count: 0 }).call
  end

  def increment_second_factor_attempts
    user.second_factor_attempts_count += 1
    attributes = {}
    attributes[:second_factor_locked_at] = Time.zone.now if user.max_login_attempts?

    UpdateUser.new(user: user, attributes: attributes).call
  end

  def create_phone_configuration
    return if duplicate_phone?
    user.phone_configurations.create!(
      phone: phone,
      delivery_preference: delivery_method,
      made_default_at: default_phone ? Time.zone.now : nil,
      confirmed_at: Time.zone.now,
    )
  end

  def duplicate_phone?
    MfaContext.new(user).phone_configurations.map(&:phone).index(phone)
  end

  def extra_analytics_attributes
    {
      code_expired: phone_confirmation_session.expired?,
      code_matches: phone_confirmation_session.matches_code?(code),
      second_factor_attempts_count: user.second_factor_attempts_count,
      second_factor_locked_at: user.second_factor_locked_at,
    }
  end
end
