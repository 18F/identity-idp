# frozen_string_literal: true

module TwoFactorAuthentication
  class WebauthnPlatformSelectionPresenter < SelectionPresenter
    def method
      :webauthn_platform
    end

    def render_in(view_context, &block)
      view_context.render(
        WebauthnInputComponent.new(
          platform: true,
          passkey_supported_only: configuration.blank?,
          show_unsupported_passkey:
            configuration.blank? &&
            IdentityConfig.store.show_unsupported_passkey_platform_authentication_setup,
        ),
        &block
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
