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
      IdentityConfig.store.select_multiple_mfa_options ?
          t('two_factor_authentication.two_factor_choice_options.phone_info_html') :
          t('two_factor_authentication.two_factor_choice_options.phone_info')
    end

    def mfa_configuration
      return '' if !disabled?
      t(
        'two_factor_authentication.two_factor_choice_options.configurations_added',
        count: user.phone_configurations.count,
      )
    end

    def security_level
      t('two_factor_authentication.two_factor_choice_options.less_secure_label')
    end

    def disabled?
      VendorStatus.new.all_phone_vendor_outage? || user.phone_configurations.any?
    end
  end
end
