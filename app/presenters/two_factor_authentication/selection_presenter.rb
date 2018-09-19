module TwoFactorAuthentication
  class SelectionPresenter
    include Rails.application.routes.url_helpers
    include ActionView::Helpers::TranslationHelper

    attr_reader :configuration

    def initialize(configuration = nil)
      @configuration = configuration
    end

    def type
      method.to_s
    end

    def label
      t("two_factor_authentication.login_options.#{method}")
    end

    def info
      t("two_factor_authentication.login_options.#{method}_info")
    end
  end
end
