module TwoFactorAuthentication
  class SignInVoiceSelectionPresenter < SignInPhoneSelectionPresenter
    def method
      :voice
    end

    def label
      t('two_factor_authentication.login_options.voice')
    end

    def info
      if configuration.present?
        t(
          'two_factor_authentication.login_options.voice_info_html',
          phone: configuration.masked_phone,
        )
      else
        super
      end
    end

    def disabled?
      OutageStatus.new.vendor_outage?(:voice)
    end
  end
end
