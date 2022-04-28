module TwoFactorAuthentication
  class VoiceSelectionPresenter < PhoneSelectionPresenter
    def method
      :voice
    end

    def type
      if MfaContext.new(configuration&.user).phone_configurations.many?
        "#{super}_#{configuration.id}"
      else
        super
      end
    end

    def info
      if configuration.present?
        t(
          'two_factor_authentication.login_options.voice_info_html',
          phone: configuration.masked_phone,
        )
      else
        voip_note = if IdentityConfig.store.voip_block
          t('two_factor_authentication.two_factor_choice_options.phone_info_no_voip')
        end

        safe_join(
          [t('two_factor_authentication.two_factor_choice_options.phone_info'), *voip_note],
          ' ',
        )
      end
    end

    def disabled?
      VendorStatus.new.vendor_outage?(:voice)
    end
  end
end
