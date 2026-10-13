# frozen_string_literal: true

module TwoFactorAuthentication
  class SetUpWebauthnSelectionPresenter < SetUpSelectionPresenter
    def type
      :webauthn
    end

    def render_in(view_context, &block)
      view_context.render(WebauthnInputComponent.new, &block)
    end

    def label
      t('two_factor_authentication.two_factor_choice_options.webauthn')
    end

    def info
      t('two_factor_authentication.two_factor_choice_options.webauthn_info')
    end

    def phishing_resistant?
      true
    end

    def mfa_configuration_count
      MfaContext.new(user).webauthn_roaming_configurations.count
    end
  end
end
