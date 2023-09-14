module TwoFactorAuthentication
  class SignInSelectionPresenter
    include ActionView::Helpers::TranslationHelper

    attr_reader :configuration, :user

    def initialize(user:, configuration:)
      @user = user
      @configuration = configuration
    end

    def render_in(view_context, &block)
      view_context.capture(&block)
    end

    def type
      method.to_s
    end

    def label
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

    def info
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
  end
end
