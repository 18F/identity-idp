module OtpDeliveryPreferenceValidator
  extend ActiveSupport::Concern

  included do
    validate :otp_delivery_preference_supported
  end

  def otp_delivery_preference_supported?
    return true unless otp_delivery_preference == 'voice'
    !phone_number_capabilities.sms_only?
  end

  def otp_delivery_preference_supported
    return if otp_delivery_preference_supported?

    errors.add(
      :phone,
      I18n.t(
        'devise.two_factor_authentication.otp_delivery_preference.phone_unsupported',
        location: phone_number_capabilities.unsupported_location
      )
    )
  end

  private

  def phone_number_capabilities
    @phone_number_capabilities ||= PhoneNumberCapabilities.new(phone)
  end
end
