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

    ###
    ### Method-specific data management
    ###
    def phone
      user&.phone
    end

    def preferred?
      user&.otp_delivery_preference.to_s == method.to_s
    end

    def authenticate(code)
      return false unless code.match? pattern_matching_otp_code_format
      user.authenticate_direct_otp(code)
    end

    def pattern_matching_otp_code_format
      /\A\d{#{otp_code_length}}\Z/
    end

    # :reek:UtilityFunction
    def otp_code_length
      Devise.direct_otp_length
    end
  end
end
