# frozen_string_literal: true

module TwoFactorAuthentication
  class SetUpPhoneSelectionPresenter < SetUpSelectionPresenter
    def type
      :phone
    end

    def label
      t('two_factor_authentication.two_factor_choice_options.phone')
    end

    def info
      t('two_factor_authentication.two_factor_choice_options.phone_info')
    end

    def phishing_resistant?
      false
    end

    def visible?
      return false if IdentityConfig.store.hide_phone_mfa_signup
      super
    end

    def mfa_configuration_count
      user.phone_configurations.count
    end

    def disabled?
      OutageStatus.new.all_phone_vendor_outage?
    end
  end
end
