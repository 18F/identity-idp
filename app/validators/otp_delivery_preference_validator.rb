module OtpDeliveryPreferenceValidator
  extend ActiveSupport::Concern

  included do
    validate :otp_delivery_preference_supported
  end

  def otp_delivery_preference_supported
    capabilities = PhoneNumberCapabilities.new(phone)
    return unless otp_delivery_preference == 'voice' && capabilities.sms_only?

    errors.add(
      :phone,
      I18n.t(
        'devise.two_factor_authentication.otp_delivery_preference.phone_unsupported',
        location: capabilities.unsupported_location
      )
    )
  end
end
