module TwoFactorAuthCode
  class PhoneDeliveryPresenter < TwoFactorAuthCode::GenericDeliveryPresenter
    def header
      t('devise.two_factor_authentication.header_text')
    end

    def help_text
      t("instructions.mfa.#{otp_delivery_preference}.confirm_code_html",
        number: phone_number_tag,
        resend_code_link: resend_code_link)
    end

    def fallback_links
      [
        otp_fallback_options,
        update_phone_link,
        personal_key_link,
      ].compact
    end

    def cancel_link
      if confirmation_for_phone_change || reauthn
        account_path
      else
        sign_out_path
      end
    end

    private

    attr_reader(
      :totp_enabled,
      :reenter_phone_number_path,
      :phone_number,
      :unconfirmed_phone,
      :otp_delivery_preference,
      :confirmation_for_phone_change
    )

    def phone_number_tag
      content_tag(:strong, phone_number)
    end

    def otp_fallback_options
      safe_join([phone_fallback_link, auth_app_fallback_link])
    end

    def update_phone_link
      return unless unconfirmed_phone

      link = view.link_to(t('forms.two_factor.try_again'), reenter_phone_number_path)
      t('instructions.mfa.wrong_number_html', link: link)
    end

    def phone_fallback_link
      t(fallback_instructions, link: phone_link_tag)
    end

    def phone_link_tag
      view.link_to(
        t("links.two_factor_authentication.#{fallback_method}"),
        otp_send_path(otp_delivery_selection_form: { otp_delivery_preference: fallback_method })
      )
    end

    def auth_app_fallback_link
      return empty unless totp_enabled

      t('links.phone_confirmation.auth_app_fallback_html', link: auth_app_fallback_tag)
    end

    def empty
      '.'
    end

    def auth_app_fallback_tag
      view.link_to(
        t('links.two_factor_authentication.app'),
        login_two_factor_authenticator_path
      )
    end

    def fallback_instructions
      "instructions.mfa.#{otp_delivery_preference}.fallback_html"
    end

    def fallback_method
      if otp_delivery_preference == 'voice'
        'sms'
      elsif otp_delivery_preference == 'sms'
        'voice'
      end
    end

    def resend_code_link
      view.link_to(
        t("links.two_factor_authentication.resend_code.#{otp_delivery_preference}"),
        otp_send_path(
          otp_delivery_selection_form: {
            otp_delivery_preference: otp_delivery_preference,
            resend: true,
          }
        )
      )
    end
  end
end
