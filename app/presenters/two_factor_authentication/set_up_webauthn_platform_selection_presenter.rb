# frozen_string_literal: true

module TwoFactorAuthentication
  class SetUpWebauthnPlatformSelectionPresenter < SetUpSelectionPresenter
    def type
      :webauthn_platform
    end

    def render_in(view_context, &block)
      view_context.render(
        WebauthnInputComponent.new(
          platform: true,
          passkey_supported_only: true,
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

    def phishing_resistant?
      true
    end

    def single_configuration_only?
      true
    end

    def mfa_configuration_count
      user.webauthn_configurations.where(platform_authenticator: true).count
    end
  end
end
