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

  def otp_delivery_preference_supported
    return if otp_delivery_preference_supported?

    errors.add(
      :phone,
      I18n.t(
        'two_factor_authentication.otp_delivery_preference.phone_unsupported',
        location: phone_number_capabilities.unsupported_location,
      ),
    )
  end

  private

  def phone_number_capabilities
    @phone_number_capabilities ||= PhoneNumberCapabilities.new(phone)
  end
end
