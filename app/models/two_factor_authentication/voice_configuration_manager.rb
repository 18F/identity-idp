module TwoFactorAuthentication
  class VoiceConfigurationManager < TwoFactorAuthentication::PhoneConfigurationManager
    def available?
      super && !PhoneNumberCapabilities.new(phone).sms_only?
    end
  end
end
