class OtpPreferenceUpdater
  def initialize(user:, preference:, phone_id:, default: nil)
    @user = user
    @preference = preference
    @default = default
    @phone_id = phone_id
  end

  def call
    return false unless user
    return false unless phone_configuration_changed?
    user_attributes = { otp_delivery_preference: preference,
                        phone_id: phone_id,
                        otp_make_default_number: default }
    UpdateUser.new(user: user, attributes: user_attributes).call
  end

  private

  attr_reader :user, :preference, :phone_id, :default

  def phone_configuration_changed?
    return true if preference != phone_delivery_preference
    return true if default && not_default_phone_configuration?
    false
  end

  def phone_configuration
    MfaContext.new(user).phone_configuration(phone_id)
  end

  def phone_delivery_preference
    return nil if phone_configuration.blank?
    phone_configuration.delivery_preference
  end

  def not_default_phone_configuration?
    phone_configuration != user.default_phone_configuration
  end
end
