module TwoFactorAuthCode
  class PhoneDeliveryPresenter < TwoFactorAuthCode::GenericDeliveryPresenter
    include TwoFactorAuthCode::Totpable
    include TwoFactorAuthCode::Phoneable

    def header
      t('devise.two_factor_authentication.header_text')
    end

    def help_text
      t("instructions.2fa.#{delivery_method}.confirm_code_html",
        number: phone_number_tag,
        resend_code_link: resend_code_link)
    end

    def fallback_links
      [
        otp_fallback_options,
        update_phone_link,
        recovery_code_link
      ].compact
    end

    private

    def otp_fallback_options
      safe_join([phone_fallback_link, auth_app_fallback_link])
    end

    def resend_code_link
      link_to(t("links.two_factor_authentication.resend_code.#{delivery_method}"),
              resend_code_path)
    end
  end
end
