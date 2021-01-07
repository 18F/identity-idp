module TwoFactorAuthentication
  class PhoneSelectionPresenter < SelectionPresenter
    def method
      :phone
    end

    def type
      if MfaContext.new(configuration&.user).phone_configurations.many?
        "#{super}_#{configuration.id}"
      else
        super
      end
    end

    def info
      if configuration.present?
        t(
          "two_factor_authentication.#{option_mode}.phone_info_html",
          phone: masked_number(configuration.phone),
        )
      else
        t("two_factor_authentication.#{option_mode}.phone_info_html")
      end
    end

    def security_level
      I18n.t('two_factor_authentication.two_factor_choice_options.less_secure_label')
    end

    private

    def masked_number(number)
      return '' if number.blank?
      "***-***-#{number[-4..-1]}"
    end
  end
end
