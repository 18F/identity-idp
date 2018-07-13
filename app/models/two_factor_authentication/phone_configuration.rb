module TwoFactorAuthentication
  class PhoneConfiguration < MethodConfiguration
    def enabled?
      phone.present? && available?
    end

    def configured?
      phone.present?
    end

    def available?
      true
    end

    ###
    ### Method-specific data management
    ###
    def phone
      user&.phone
    end

    def preferred?
      user&.otp_delivery_preference.to_s == method.to_s
    end
  end
end
