module TwoFactorAuthentication
  class SignInWebauthnSelectionPresenter < SignInSelectionPresenter
    def type
      :webauthn
    end

    def render_in(view_context, &block)
      view_context.render(WebauthnInputComponent.new, &block)
    end

    def label
      t('two_factor_authentication.login_options.webauthn')
    end

    def info
      t('two_factor_authentication.login_options.webauthn_info')
    end
  end
end
