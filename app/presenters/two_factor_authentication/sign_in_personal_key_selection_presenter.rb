module TwoFactorAuthentication
  class SignInPersonalKeySelectionPresenter < SelectionPresenter
    def method
      :personal_key
    end

    def label
      t('two_factor_authentication.login_options.personal_key')
    end

    def info
      t('two_factor_authentication.login_options.personal_key_info')
    end
  end
end
