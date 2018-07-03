module TwoFactorAuthentication
  class SelectionPresenter
    include Rails.application.routes.url_helpers
    include ActionView::Helpers::TranslationHelper

    attr_reader :configuration_manager

    def initialize(configuration_manager)
      @configuration_manager = configuration_manager
    end

    def method
      @method ||= begin
        self.class.name.demodulize.sub(/SelectionPresenter$/, '').snakecase.to_sym
      end
    end

    def label
      t("devise.two_factor_authentication.two_factor_choice_options.#{method}")
    end

    def info
      t("devise.two_factor_authentication.two_factor_choice_options.#{method}_info")
    end
  end
end
