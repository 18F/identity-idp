module Idv
  class OtpVerificationPresenter
    include ActionView::Helpers::UrlHelper
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::TranslationHelper

    attr_reader :idv_session

    def initialize(idv_session:)
      @idv_session = idv_session
    end

    def phone_number_message
      t(
        "instructions.mfa.#{otp_delivery_preference}.number_message_html",
        number_html: content_tag(:strong, phone_number),
        expiration: TwoFactorAuthenticatable::DIRECT_OTP_VALID_FOR_MINUTES,
      )
    end

    private

    def phone_number
      idv_session.user_phone_confirmation_session.phone
    end

    def otp_delivery_preference
      idv_session.user_phone_confirmation_session.delivery_method
    end
  end
end
