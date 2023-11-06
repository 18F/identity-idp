module TwoFactorAuthentication
  class SetUpSmsSelectionPresenter < SetUpPhoneSelectionPresenter
    def method
      :sms
    end

    def label
      t('two_factor_authentication.two_factor_choice_options.sms')
    end

    def info
      if configuration.present?
        t(
          'two_factor_authentication.login_options.sms_info_html',
          phone: configuration.masked_phone,
        )
      else
        super
      end
    end

    def disabled?
      OutageStatus.new.vendor_outage?(:sms)
    end
  end
end
