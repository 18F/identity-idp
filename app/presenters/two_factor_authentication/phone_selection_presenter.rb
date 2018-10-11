module TwoFactorAuthentication
  class PhoneSelectionPresenter < SelectionPresenter
    def type
      if MfaContext.new(configuration&.user).phone_configurations.many?
        "#{super}:#{configuration.id}"
      else
        super
      end
    end

    def info
      if configuration.present?
        t("two_factor_authentication.login_options.#{method}_info_html", phone: configuration.phone)
      else
        t("two_factor_authentication.login_options.#{method}_setup_info")
      end
    end
  end
end
