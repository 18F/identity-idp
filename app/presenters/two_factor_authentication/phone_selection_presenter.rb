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
      t('two_factor_authentication.two_factor_choice_options.phone_info')
    end

    def mfa_configuration_count
      user.phone_configurations.count
    end

    def disabled?
      VendorStatus.new.all_phone_vendor_outage? || user&.phone_configurations&.any?
    end
  end
end
