module TwoFactorAuthentication
  class SetUpWebauthnPlatformSelectionPresenter < SetUpSelectionPresenter
    def initialize(user:, configuration: nil)
      @user = user
      @configuration = configuration
    end

    def method
      :webauthn_platform
    end

    def render_in(view_context, &block)
      view_context.render(
        WebauthnInputComponent.new(
          platform: true,
          passkey_supported_only: true,
          show_unsupported_passkey:
            IdentityConfig.store.show_unsupported_passkey_platform_authentication_setup,
        ),
        &block
      )
    end

    def label
      t('two_factor_authentication.two_factor_choice_options.webauthn_platform')
    end

    def info
      t(
        'two_factor_authentication.two_factor_choice_options.webauthn_platform_info',
        app_name: APP_NAME,
      )
    end

    def single_configuration_only?
      true
    end

    def mfa_configuration_count
      user.webauthn_configurations.where(platform_authenticator: true).count
    end
  end
end
