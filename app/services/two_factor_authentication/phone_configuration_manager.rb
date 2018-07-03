module TwoFactorAuthentication
  class PhoneConfigurationManager < ConfigurationManager
    def enabled?
      phone.present? && available?
    end

    def configured?
      phone.present?
    end

    def available?
      true
    end

    def setup_path
      phone_setup_path
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
