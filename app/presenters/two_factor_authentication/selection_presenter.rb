module TwoFactorAuthentication
  class SelectionPresenter
    include ActionView::Helpers::TranslationHelper

    attr_reader :configuration, :user

    def initialize(configuration: nil, user: nil)
      @configuration = configuration
      @user = user
    end

    def type
      method.to_s
    end

    def label
      if @configuration.present?
        login_label(method.to_s)
      else
        setup_label(method.to_s)
      end
    end

    def info
      if @configuration.present?
        login_info(method.to_s)
      else
        setup_info(method.to_s)
      end
    end

    def mfa_configuration_count; end

    def mfa_configuration_description
      return '' if !disabled?
      t(
        'two_factor_authentication.two_factor_choice_options.configurations_added',
        count: mfa_configuration_count,
      )
    end

    def html_class
      ''
    end

    def disabled?
      false
    end

    private

    def login_label(type)
      case type
      when 'auth_app'
        t('two_factor_authentication.login_options.auth_app')
      when 'backup_code'
        t('two_factor_authentication.login_options.backup_code')
      when 'personal_key'
        t('two_factor_authentication.login_options.personal_key')
      when 'piv_cac'
        t('two_factor_authentication.login_options.piv_cac')
      when 'sms'
        t('two_factor_authentication.login_options.sms')
      when 'voice'
        t('two_factor_authentication.login_options.voice')
      when 'webauthn'
        t('two_factor_authentication.login_options.webauthn')
      when 'webauthn_platform'
        t('two_factor_authentication.login_options.webauthn_platform')
      else
        raise "Unsupported login method: #{type}"
      end
    end

    def setup_label(type)
      case type
      when 'auth_app'
        t('two_factor_authentication.two_factor_choice_options.auth_app')
      when 'backup_code'
        t('two_factor_authentication.two_factor_choice_options.backup_code')
      when 'piv_cac'
        t('two_factor_authentication.two_factor_choice_options.piv_cac')
      when 'phone'
        t('two_factor_authentication.two_factor_choice_options.phone')
      when 'sms'
        t('two_factor_authentication.two_factor_choice_options.sms')
      when 'voice'
        t('two_factor_authentication.two_factor_choice_options.voice')
      when 'webauthn'
        t('two_factor_authentication.two_factor_choice_options.webauthn')
      when 'webauthn_platform'
        t('two_factor_authentication.two_factor_choice_options.webauthn_platform')
      else
        raise "Unsupported setup method: #{type}"
      end
    end

    def login_info(type)
      case type
      when 'auth_app'
        t('two_factor_authentication.login_options.auth_app_info')
      when 'backup_code'
        t('two_factor_authentication.login_options.backup_code_info')
      when 'personal_key'
        t('two_factor_authentication.login_options.personal_key_info')
      when 'piv_cac'
        t('two_factor_authentication.login_options.piv_cac_info')
      when 'webauthn'
        t('two_factor_authentication.login_options.webauthn_info')
      when 'webauthn_platform'
        t('two_factor_authentication.login_options.webauthn_platform_info', app_name: APP_NAME)
      else
        raise "Unsupported login method: #{type}"
      end
    end

    def setup_info(type)
      case type
      when 'auth_app'
        t('two_factor_authentication.two_factor_choice_options.auth_app_info')
      when 'backup_code'
        t('two_factor_authentication.two_factor_choice_options.backup_code_info')
      when 'piv_cac'
        t('two_factor_authentication.two_factor_choice_options.piv_cac_info')
      when 'webauthn'
        t('two_factor_authentication.two_factor_choice_options.webauthn_info')
      when 'webauthn_platform'
        t(
          'two_factor_authentication.two_factor_choice_options.webauthn_platform_info',
          app_name: APP_NAME,
        )
      else
        raise "Unsupported setup method: #{type}"
      end
    end
  end
end
