module TwoFactorAuthentication
  class SmsSelectionPresenter < PhoneSelectionPresenter
    def method
      :sms
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
      VendorStatus.new.vendor_outage?(:sms)
    end
  end
end
