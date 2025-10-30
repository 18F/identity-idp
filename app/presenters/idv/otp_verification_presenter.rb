# frozen_string_literal: true

module Idv
  class OtpVerificationPresenter
    include ActionView::Helpers::UrlHelper
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::TranslationHelper
    include LinkHelper

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

    def do_not_share_code_message
      t(
        'instructions.mfa.do_not_share_code_message_html',
        app_name: APP_NAME,
        link_html: new_tab_link_to(
          t('instructions.mfa.do_not_share_code_link_text'),
          MarketingSite.help_center_article_url(
            category: 'fraud-concerns',
            article: 'overview',
          ),
        ),
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
