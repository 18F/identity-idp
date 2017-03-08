module TwoFactorAuthCode
  class AuthenticatorDeliveryPresenter < TwoFactorAuthCode::GenericDeliveryPresenter
    def header
      t('devise.two_factor_authentication.totp_header_text')
    end

    def help_text
      t("instructions.2fa.#{delivery_method}.confirm_code_html",
        email: content_tag(:strong, user_email),
        app: content_tag(:strong, APP_NAME),
        tooltip: view.tooltip(t('tooltips.authentication_app')))
    end

    def fallback_links
      [otp_fallback_options, recovery_code_link].compact
    end

    private

    def otp_fallback_options
      t('devise.two_factor_authentication.totp_fallback.text_html',
        sms_link: sms_link,
        voice_link: voice_link)
    end

    def sms_link
      link_to(t('devise.two_factor_authentication.totp_fallback.sms_link_text'),
              otp_send_path(otp_delivery_selection_form: { otp_method: 'sms' }))
    end

    def voice_link
      sr_only = content_tag(
        :span,
        t('devise.two_factor_authentication.totp_fallback.voice_link_text_sr_only'),
        class: 'hide'
      )

      link_to(
        t('devise.two_factor_authentication.totp_fallback.voice_link_text_html', sr_only: sr_only),
        otp_send_path(otp_delivery_selection_form: { otp_method: 'voice' })
      )
    end
  end
end
