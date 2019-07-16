module TwoFactorAuthCode
  class PhoneDeliveryPresenter < TwoFactorAuthCode::GenericDeliveryPresenter
    attr_reader(
      :otp_delivery_preference, :otp_make_default_number
    )

    def header
      t('two_factor_authentication.header_text')
    end

    def phone_number_message
      t("instructions.mfa.#{otp_delivery_preference}.number_message_html",
        number: content_tag(:strong, phone_number),
        expiration: Figaro.env.otp_valid_for)
    end

    def fallback_question
      t('two_factor_authentication.phone_fallback.question')
    end

    def help_text
      ''
    end

    def update_phone_link
      return unless unconfirmed_phone

      link = view.link_to(t('forms.two_factor.try_again'), reenter_phone_number_path)
      t('instructions.mfa.wrong_number_html', link: link)
    end

    def cancel_link
      locale = LinkLocaleResolver.locale
      if confirmation_for_phone_change || reauthn
        account_path(locale: locale)
      else
        sign_out_path(locale: locale)
      end
    end

    private

    attr_reader(
      :reenter_phone_number_path,
      :phone_number,
      :unconfirmed_phone,
      :account_reset_token,
      :confirmation_for_phone_change,
      :voice_otp_delivery_unsupported,
    )
  end
end
