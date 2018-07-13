module TwoFactorAuthentication
  class VoiceConfiguration < PhoneConfiguration
    def available?
      super && !PhoneNumberCapabilities.new(phone).sms_only?
    end
  end
end
