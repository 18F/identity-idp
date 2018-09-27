module TwoFactorAuthCode
  class AuthenticatorDeliveryPresenter < TwoFactorAuthCode::GenericDeliveryPresenter
    def header
      t('two_factor_authentication.totp_header_text')
    end

    def help_text
      t("instructions.mfa.#{two_factor_authentication_method}.confirm_code_html",
        email: content_tag(:strong, user_email),
        app: content_tag(:strong, APP_NAME),
        tooltip: view.tooltip(t('tooltips.authentication_app')))
    end

    def fallback_question
      t('two_factor_authentication.totp_fallback.question')
    end

    def cancel_link
      locale = LinkLocaleResolver.locale
      if reauthn
        account_path(locale: locale)
      else
        sign_out_path(locale: locale)
      end
    end

    private

    attr_reader :user_email, :two_factor_authentication_method, :phone_enabled
  end
end
