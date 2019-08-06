class OtpPreferenceUpdater
  def initialize(user:, preference:, phone_id: nil, default: nil)
    @user = user
    @preference = preference
    @default = default
    @phone_id = phone_id
  end

  def call
    user_attributes = { otp_delivery_preference: preference,
                        phone_id: phone_id,
                        otp_make_default_number: default }
    UpdateUser.new(user: user, attributes: user_attributes).call if should_update_user?
  end

  private

  attr_reader :user, :preference, :phone_id, :default

  def should_update_user?
    return false unless user
    otp_delivery_preference_changed?
  end

  def otp_delivery_preference_changed?
    return true if (preference != user.otp_delivery_preference)
    phone_configuration = MfaContext.new(user).phone_configuration(phone_id)
    phone_configuration.present? && preference != phone_configuration.delivery_preference
  end
end
