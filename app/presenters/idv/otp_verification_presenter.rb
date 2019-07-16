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
      t("instructions.mfa.#{otp_delivery_preference}.number_message_html",
        number: content_tag(:strong, phone_number),
        expiration: Figaro.env.otp_valid_for)
    end

    def update_phone_link
      phone_path = Rails.application.routes.url_helpers.idv_phone_path
      link = link_to(t('forms.two_factor.try_again'), phone_path)
      t('instructions.mfa.wrong_number_html', link: link)
    end

    private

    def phone_number
      PhoneFormatter.format(idv_session.applicant[:phone])
    end

    def otp_delivery_preference
      idv_session.phone_confirmation_otp_delivery_method
    end
  end
end
