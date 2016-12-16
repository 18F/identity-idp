module TwoFactorAuthCode
  class OtpDeliveryPresenter < TwoFactorAuthCode::GenericDeliveryModePresenter
    include TwoFactorAuthCode::Phoneable

    def initialize(data_model)
      super
    end

    def header
      t('headings.choose_otp_delivery')
    end

    def help_text
      t('devise.two_factor_authentication.choose_otp_delivery',
        phone: phone_number_tag(phone_number))
    end

    def fallback_links
      [
        recovery_code_link,
        update_phone_link(unconfirmed_phone, reenter_phone_number_path)
      ].compact
    end
  end
end
