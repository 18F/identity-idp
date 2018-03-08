module TwoFactorAuthCode
  class PhoneDeliveryPresenter < TwoFactorAuthCode::GenericDeliveryPresenter
    def header
      t('devise.two_factor_authentication.header_text')
    end

    def phone_number_message
      t("instructions.mfa.#{otp_delivery_preference}.number_message",
        number: content_tag(:strong, phone_number),
        expiration: Figaro.env.otp_valid_for)
    end

    def help_text
      t("instructions.mfa.#{otp_delivery_preference}.confirm_code_html",
        resend_code_link: view.link_to(
          t("links.two_factor_authentication.resend_code.#{otp_delivery_preference}"),
          otp_send_path(locale: LinkLocaleResolver.locale,
                        otp_delivery_selection_form:
                          { otp_delivery_preference: otp_delivery_preference, resend: true })
        ))
    end

    def fallback_links
      [otp_fallback_options, update_phone_link, personal_key_link, reset_2fa_device_link].compact
    end

    def cancel_link
      locale = LinkLocaleResolver.locale
      if confirmation_for_phone_change || reauthn
        account_path(locale: locale)
      elsif confirmation_for_idv
        verify_cancel_path(locale: locale)
      else
        sign_out_path(locale: locale)
      end
    end

    private

    attr_reader(
      :totp_enabled,
      :reenter_phone_number_path,
      :phone_number,
      :phone_confirmed_at,
      :unconfirmed_phone,
      :otp_delivery_preference,
      :reset_device_token,
      :confirmation_for_phone_change,
      :voice_otp_delivery_unsupported,
      :confirmation_for_idv
    )

    def otp_fallback_options
      if totp_enabled
        otp_fallback_options_with_totp
      elsif !voice_otp_delivery_unsupported
        safe_join([phone_fallback_link, '.'])
      end
    end

    def otp_fallback_options_with_totp
      if voice_otp_delivery_unsupported
        safe_join([auth_app_fallback_tag, '.'])
      else
        safe_join([phone_fallback_link, auth_app_fallback_link])
      end
    end

    def update_phone_link
      return unless unconfirmed_phone
      link = view.link_to(t('forms.two_factor.try_again'), reenter_phone_number_path)
      t('instructions.mfa.wrong_number_html', link: link)
    end

    def phone_fallback_link
      t("instructions.mfa.#{otp_delivery_preference}.fallback_html",
        link: view.link_to(
          t("links.two_factor_authentication.#{fallback_method}"),
          otp_send_path(locale: LinkLocaleResolver.locale, otp_delivery_selection_form:
            { otp_delivery_preference: fallback_method })
        ))
    end

    def reset_2fa_device_link
      return unless show_reset_device_info?
      if reset_device_token
        t('devise.two_factor_authentication.reset_device.pending_html', cancel_link:
          view.link_to(t('devise.two_factor_authentication.reset_device.cancel_link'),
                       reset_device_cancel_url(token: reset_device_token, only: 1)))
      else
        t('devise.two_factor_authentication.reset_device.text_html', link:
          view.link_to(t('devise.two_factor_authentication.reset_device.link'),
                       login_two_factor_reset_device_path(locale: LinkLocaleResolver.locale)))
      end
    end

    def show_reset_device_info?
      phone_confirmed_at && Figaro.env.reset_device_enabled == 'true'
    end

    def auth_app_fallback_link
      t('links.phone_confirmation.auth_app_fallback_html', link: auth_app_fallback_tag)
    end

    def auth_app_fallback_tag
      view.link_to(
        t('links.two_factor_authentication.app'),
        login_two_factor_authenticator_path(locale: LinkLocaleResolver.locale)
      )
    end

    def fallback_method
      return 'sms' if otp_delivery_preference == 'voice'
      return 'voice' if otp_delivery_preference == 'sms'
    end
  end
end
