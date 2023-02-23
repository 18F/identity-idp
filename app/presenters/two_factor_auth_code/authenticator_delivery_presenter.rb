module TwoFactorAuthCode
  class AuthenticatorDeliveryPresenter < TwoFactorAuthCode::GenericDeliveryPresenter
    def header
      t('two_factor_authentication.totp_header_text')
    end

    def help_text
      t(
        "instructions.mfa.#{two_factor_authentication_method}.confirm_code_html",
        app_name: content_tag(:strong, APP_NAME),
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

    private

    attr_reader :two_factor_authentication_method
  end
end
