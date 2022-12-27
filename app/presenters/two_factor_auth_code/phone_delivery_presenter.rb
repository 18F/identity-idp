module TwoFactorAuthCode
  class PhoneDeliveryPresenter < TwoFactorAuthCode::GenericDeliveryPresenter
    attr_reader :otp_delivery_preference,
                :otp_make_default_number,
                :unconfirmed_phone,
                :otp_expiration

    alias_method :unconfirmed_phone?, :unconfirmed_phone

    def header
      t('two_factor_authentication.header_text')
    end

    def phone_number_message
      t(
        "instructions.mfa.#{otp_delivery_preference}.number_message_html",
        number: content_tag(:strong, phone_number),
        expiration: TwoFactorAuthenticatable::DIRECT_OTP_VALID_FOR_MINUTES,
      )
    end

    def fallback_question
      t('two_factor_authentication.phone_fallback.question')
    end

    def help_text
      ''
    end

    def cancel_link
      locale = LinkLocaleResolver.locale
      if confirmation_for_add_phone || reauthn
        account_path(locale: locale)
      else
        sign_out_path(locale: locale)
      end
    end

    private

    attr_reader(
      :phone_number,
      :account_reset_token,
      :confirmation_for_add_phone,
      :voice_otp_delivery_unsupported,
    )
  end
end
