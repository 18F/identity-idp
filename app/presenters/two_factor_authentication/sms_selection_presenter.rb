module TwoFactorAuthentication
  class SmsSelectionPresenter < PhoneSelectionPresenter
    def method
      :sms
    end

    def disabled?
      VendorStatus.new.vendor_outage?(:sms)
    end
  end
end
