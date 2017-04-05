module TwoFactorAuthCode
  class AuthenticatorDeliveryPresenter < TwoFactorAuthCode::GenericDeliveryPresenter
    attr_reader :two_factor_authentication_method

    def header
      t('devise.two_factor_authentication.totp_header_text')
    end

    def help_text
      t("instructions.2fa.#{two_factor_authentication_method}.confirm_code_html",
        email: content_tag(:strong, user_email),
        app: content_tag(:strong, APP_NAME),
        tooltip: view.tooltip(t('tooltips.authentication_app')))
    end

    def fallback_links
      [otp_fallback_options, personal_key_link].compact
    end

    private

    def otp_fallback_options
      t('devise.two_factor_authentication.totp_fallback.text_html',
        sms_link: sms_link,
        voice_link: voice_link)
    end

    def sms_link
      link_to(t('devise.two_factor_authentication.totp_fallback.sms_link_text'),
              otp_send_path(otp_delivery_selection_form: { otp_delivery_preference: 'sms' }))
    end

    def voice_link
      link_to(t('devise.two_factor_authentication.totp_fallback.voice_link_text'),
              otp_send_path(otp_delivery_selection_form: { otp_delivery_preference: 'voice' }))
    end
  end
end
