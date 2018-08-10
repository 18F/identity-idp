module Idv
  class OtpVerificationPresenter
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::TranslationHelper

    attr_reader :idv_session

    def initialize(idv_session:)
      @idv_session = idv_session
    end

    def phone_number_message
      t("instructions.mfa.#{otp_delivery_preference}.number_message",
        number: content_tag(:strong, phone_number),
        expiration: Figaro.env.otp_valid_for)
    end

    private

    def phone_number
      PhoneFormatter.format(idv_session.params[:phone])
    end

    def otp_delivery_preference
      idv_session.phone_confirmation_otp_delivery_method
    end
  end
end
