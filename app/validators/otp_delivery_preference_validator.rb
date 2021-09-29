module OtpDeliveryPreferenceValidator
  extend ActiveSupport::Concern

  included do
    validate :otp_delivery_preference_supported
  end

  def otp_delivery_preference_supported?
    case otp_delivery_preference
    when 'voice'
      phone_number_capabilities.supports_voice?
    when 'sms'
      phone_number_capabilities.supports_sms?
    end
  end

  def invalid_otp_delivery_preference?
    !%w[voice sms].include?(otp_delivery_preference)
  end

  def otp_delivery_preference_supported
    return if invalid_otp_delivery_preference?
    return if otp_delivery_preference_supported?

    errors.add(
      :phone,
      I18n.t(
        'two_factor_authentication.otp_delivery_preference.voice_unsupported',
        location: phone_number_capabilities.unsupported_location,
      ),
    )
  end

  private

  def phone_number_capabilities
    @phone_number_capabilities ||= PhoneNumberCapabilities.new(
      phone,
      phone_confirmed: confirmed_phone?,
    )
  end
end
