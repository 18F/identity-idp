module TwoFactorAuthCode
  class AuthenticatorDeliveryPresenter < TwoFactorAuthCode::GenericDeliveryPresenter
    def header
      t('two_factor_authentication.totp_header_text')
    end

    def help_text
      t(
        'instructions.mfa.authenticator.confirm_code_html',
        app_name_html: content_tag(:strong, APP_NAME),
      )
    end

    def fallback_question
      t('two_factor_authentication.totp_fallback.question')
    end

    def cancel_link
      if reauthn
        account_path
      else
        sign_out_path
      end
    end
  end
end
