module TwoFactorAuthentication
  class SecondPhoneSelectionPresenter < PhoneSelectionPresenter
    attr_reader :current_phone_configuration

    def initialize(current_phone_configuration)
      @current_phone_configuration = current_phone_configuration
    end

    def method
      :phone
    end

    def label
      t('two_factor_authentication.two_factor_choice_options.second_phone')
    end

    def info
      t(
        'two_factor_authentication.two_factor_choice_options.second_phone_info_html',
        phone: current_phone_configuration.phone,
      )
    end
  end
end
