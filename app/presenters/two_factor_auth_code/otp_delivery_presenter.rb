module TwoFactorAuthCode
  class OtpDeliveryPresenter < TwoFactorAuthCode::GenericDeliveryPresenter
    include TwoFactorAuthCode::Phoneable

    def header
      t('headings.choose_otp_delivery')
    end

    def help_text
      t('devise.two_factor_authentication.choose_otp_delivery_html',
        phone: phone_number_tag)
    end

    def fallback_links
      [
        recovery_code_link,
        update_phone_link
      ].compact
    end
  end
end
