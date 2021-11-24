module TwoFactorAuthentication
  class VoiceSelectionPresenter < PhoneSelectionPresenter
    def method
      :voice
    end

    def disabled?
      VendorStatus.new.vendor_outage?(:voice)
    end
  end
end
