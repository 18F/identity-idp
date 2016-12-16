module TwoFactorAuthCode
  module Phoneable
    def phone_fallback_link(delivery_method)
      fallback_method = if delivery_method == 'voice'
                          'sms'
                        elsif delivery_method == 'sms'
                          'voice'
                        end

      t(fallback_instructions(fallback_method),
        link: phone_link_tag(fallback_method))
    end

    def update_phone_link(unconfirmed_phone, update_number_path)
      return unless unconfirmed_phone

      link = content_tag(:a, t('forms.two_factor.try_again'), href: update_number_path)
      t('instructions.2fa.wrong_number', link: link)
    end

    def phone_number_tag(phone_number)
      content_tag(:strong, phone_number)
    end

    def phone_link_tag(delivery_method)
      send_path = otp_send_path(otp_delivery_selection_form: { otp_method: delivery_method })

      content_tag(:a, t("links.two_factor_authentication.#{delivery_method}"), href: send_path)
    end

    private

    def fallback_instructions(method)
      "instructions.2fa.#{method}.fallback"
    end
  end
end
