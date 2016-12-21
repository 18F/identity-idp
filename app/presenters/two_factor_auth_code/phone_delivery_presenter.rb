module TwoFactorAuthCode
  class PhoneDeliveryPresenter < TwoFactorAuthCode::GenericDeliveryModePresenter
    include TwoFactorAuthCode::Totpable
    include TwoFactorAuthCode::Phoneable

    def initialize(data_model)
      super
    end

    def header
      t('devise.two_factor_authentication.header_text')
    end

    def help_text
      t("instructions.2fa.#{delivery_method}.confirm_code_html",
        number: phone_number_tag(phone_number),
        resend_code_link: resend_code_link)
    end

    def fallback_links
      [
        otp_fallback_options,
        update_phone_link(reenter_phone_number_path),
        recovery_code_link
      ].compact
    end

    private

    def otp_fallback_options
      auth_app = totp_enabled ? auth_app_fallback_link : empty

      safe_join([phone_fallback_link(delivery_method), auth_app])
    end

    def resend_code_link
      link_to(t("links.two_factor_authentication.resend_code.#{delivery_method}_html"),
              resend_code_path)
    end
  end
end
