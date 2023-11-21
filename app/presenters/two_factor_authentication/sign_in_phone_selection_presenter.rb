module TwoFactorAuthentication
  class SignInPhoneSelectionPresenter < SignInSelectionPresenter
    attr_reader :configuration, :user, :delivery_method

    def initialize(user:, configuration:, delivery_method:)
      @user = user
      @configuration = configuration
      @delivery_method = delivery_method
    end

    def type
      if MfaContext.new(configuration&.user).phone_configurations.many?
        "#{delivery_method}_#{configuration.id}".to_sym
      else
        delivery_method || :phone
      end
    end

    def label
      if delivery_method == :sms
        t('two_factor_authentication.login_options.sms')
      elsif delivery_method == :voice
        t('two_factor_authentication.login_options.voice')
      end
    end

    def info
      case delivery_method
      when :sms
        t(
          'two_factor_authentication.login_options.sms_info_html',
          phone: configuration.masked_phone,
        )
      when :voice
        t(
          'two_factor_authentication.login_options.voice_info_html',
          phone: configuration.masked_phone,
        )
      else
        t('two_factor_authentication.two_factor_choice_options.phone_info')
      end
    end

    def disabled?
      case delivery_method
      when :sms
        OutageStatus.new.vendor_outage?(:sms)
      when :voice
        OutageStatus.new.vendor_outage?(:voice)
      else
        OutageStatus.new.all_phone_vendor_outage?
      end
    end
  end
end
