module TwoFactorAuthCode
  class AuthenticatorDeliveryPresenter < TwoFactorAuthCode::GenericDeliveryPresenter
    def header
      t('two_factor_authentication.totp_header_text')
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
