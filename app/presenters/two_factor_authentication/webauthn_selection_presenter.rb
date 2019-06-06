module TwoFactorAuthentication
  class WebauthnSelectionPresenter < SelectionPresenter
    def method
      :webauthn
    end

    def html_class
      'hide'
    end
  end
end
