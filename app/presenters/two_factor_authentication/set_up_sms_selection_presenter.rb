module TwoFactorAuthentication
  class SetUpSmsSelectionPresenter < SetUpPhoneSelectionPresenter
    def method
      :sms
    end

    def label
      t('two_factor_authentication.two_factor_choice_options.sms')
    end

    def disabled?
      OutageStatus.new.vendor_outage?(:sms)
    end
  end
end
