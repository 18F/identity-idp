module TwoFactorAuthentication
  class SignInWebauthnPlatformSelectionPresenter < SignInSelectionPresenter
    def type
      :webauthn_platform
    end

    def render_in(view_context, &block)
      view_context.render(
        WebauthnInputComponent.new(
          platform: true,
          passkey_supported_only: false,
          show_unsupported_passkey: false,
        ),
        &block
      )
    end

    def label
      t('two_factor_authentication.login_options.webauthn_platform')
    end

    def info
      t('two_factor_authentication.login_options.webauthn_platform_info', app_name: APP_NAME)
    end
  end
end
