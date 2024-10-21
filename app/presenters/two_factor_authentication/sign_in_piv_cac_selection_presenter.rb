# frozen_string_literal: true

module TwoFactorAuthentication
  class SignInPivCacSelectionPresenter < SignInSelectionPresenter
    def type
      :piv_cac
    end

    def render_in(view_context, &block)
      @disabled = view_context.user_session.key?(:add_piv_cac_after_2fa)
      view_context.capture(&block)
    end

    def label
      t('two_factor_authentication.login_options.piv_cac')
    end

    def info
      t('two_factor_authentication.login_options.piv_cac_info')
    end

    def disabled?
      @disabled.present?
    end
  end
end
