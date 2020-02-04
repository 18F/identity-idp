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
      t("two_factor_authentication.#{option_mode}.#{method}")
    end

    def info
      t("two_factor_authentication.#{option_mode}.#{method}_info_html")
    end


    def security_level
      levels =
          { I18n.t("two_factor_authentication.two_factor_choice_options.auth_app") => I18n.t("two_factor_authentication.security_level_labels.more_secure"),
            I18n.t("two_factor_authentication.two_factor_choice_options.webauthn") => I18n.t("two_factor_authentication.security_level_labels.more_secure"),
            I18n.t("two_factor_authentication.two_factor_choice_options.piv_cac") => I18n.t("two_factor_authentication.security_level_labels.more_secure"),
            I18n.t("two_factor_authentication.two_factor_choice_options.backup_code") => I18n.t("two_factor_authentication.security_level_labels.less_secure") }.freeze

      levels[label]
    end

    def html_class
      ''
    end

    private

    def option_mode
      if @configuration.present?
        'login_options'
      else
        'two_factor_choice_options'
      end
    end
  end
end
