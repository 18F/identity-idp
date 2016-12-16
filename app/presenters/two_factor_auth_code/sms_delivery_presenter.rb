module TwoFactorAuthCode
  class SmsDeliveryPresenter < TwoFactorAuthCode::GenericDeliveryModePresenter
    include TwoFactorAuthCode::Totpable
    include TwoFactorAuthCode::Phoneable

    def initialize(data_model)
      super
    end

    def header
      t('devise.two_factor_authentication.header_text')
    end

    def help_text
      t("instructions.2fa.#{delivery_method}.confirm_code",
        number: phone_number_tag(phone_number),
        resend_code_link: resend_code_tag)
    end

    def fallback_links
      [
        otp_fallback_options,
        update_phone_link(unconfirmed_phone, reenter_phone_number_path),
        recovery_code_link
      ].compact
    end

    private

    def otp_fallback_options
      "#{phone_fallback_link(delivery_method)}#{auth_app_fallback_link(totp_enabled)}"
    end

    def resend_code_tag
      content_tag(:a,
                  t('links.two_factor_authentication.resend_code.sms'),
                  href: resend_code_path)
    end
  end
end
