module TwoFactorAuthentication
  class VoiceConfigurationManager < PhoneConfigurationManager
    def available?
      super && !PhoneNumberCapabilities.new(phone).sms_only?
    end
  end
end
