module TwoFactorAuthentication
  class WebauthnSelectionPresenter < SelectionPresenter
    def method
      :webauthn
    end

    def render_in(view_context, &block)
      view_context.render(WebauthnInputComponent.new, &block)
    end

    def disabled?
      user&.webauthn_configurations&.where(platform_authenticator: [false, nil])&.any?
    end

    def mfa_configuration_count
      user.webauthn_configurations.where(platform_authenticator: [false, nil]).count
    end
  end
end
