module TwoFactorAuthentication
  class SignInPhoneSelectionPresenter < SignInSelectionPresenter
    def initialize(user:, configuration:, method:)
      @user = user
      @configuration = configuration
      @method = method
    end

    def type
      if MfaContext.new(configuration&.user).phone_configurations.many?
        "#{super}_#{configuration.id}"
      else
        super
      end
    end

    def label
      if method.to_s == 'sms'
        t('two_factor_authentication.login_options.sms')
      elsif method.to_s == 'voice'
        t('two_factor_authentication.login_options.voice')
      end
    end

    def info
      if method.to_s == 'sms'
        t(
          'two_factor_authentication.login_options.sms_info_html',
          phone: configuration.masked_phone,
        )
      elsif method.to_s == 'voice'
        t(
          'two_factor_authentication.login_options.voice_info_html',
          phone: configuration.masked_phone,
        )
      else
        t('two_factor_authentication.two_factor_choice_options.phone_info')
      end
    end

    def disabled?
      OutageStatus.new.all_phone_vendor_outage?
    end
  end
end
