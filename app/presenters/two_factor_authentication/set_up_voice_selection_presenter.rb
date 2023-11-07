module TwoFactorAuthentication
  class SetUpVoiceSelectionPresenter < SetUpPhoneSelectionPresenter
    def method
      :voice
    end

    def label
      t('two_factor_authentication.two_factor_choice_options.voice')
    end

    def disabled?
      OutageStatus.new.vendor_outage?(:voice)
    end
  end
end
