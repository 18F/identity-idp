module Idv
  class OtpDeliveryMethodPresenter
    attr_reader :phone

    delegate :sms_only?, to: :phone_number_capabilites

    def initialize(phone)
      @phone = PhoneFormatter.new.format(phone)
    end

    def phone_unsupported_message
      I18n.t(
        'devise.two_factor_authentication.otp_delivery_preference.phone_unsupported',
        location: phone_number_capabilites.unsupported_location
      )
    end

    private

    def phone_number_capabilites
      @phone_number_capabilites ||= PhoneNumberCapabilities.new(phone)
    end
  end
end
