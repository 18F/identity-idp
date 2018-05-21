module TwoFactorAuthCode
  class GenericDeliveryPresenter
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::TranslationHelper
    include Rails.application.routes.url_helpers

    attr_reader :code_value, :remember_device_available

    def initialize(data:, view:)
      data.each do |key, value|
        instance_variable_set("@#{key}", value)
      end

      @view = view
    end

    def header
      raise NotImplementedError
    end

    def help_text
      raise NotImplementedError
    end

    def fallback_links
      raise NotImplementedError
    end

    def personal_key_link
      return if personal_key_unavailable

      t("#{personal_key}.text_html", link: personal_key_tag)
    end

    def reauthn_hidden_field_partial
      if reauthn
        'two_factor_authentication/totp_verification/reauthn'
      else
        'shared/null'
      end
    end

    def remember_device_available?
      remember_device_available
    end

    private

    attr_reader :personal_key_unavailable, :has_piv_cac_configured, :view, :reauthn

    def personal_key_tag
      view.link_to(t("#{personal_key}.link"),
                   login_two_factor_personal_key_path(locale: LinkLocaleResolver.locale))
    end

    def personal_key
      'devise.two_factor_authentication.personal_key_fallback'
    end

    def piv_cac_link
      view.link_to(
        t('devise.two_factor_authentication.piv_cac_fallback.link'),
        login_two_factor_piv_cac_path(locale: LinkLocaleResolver.locale)
      )
    end

    def piv_cac_option
      return unless FeatureManagement.piv_cac_enabled?
      return unless has_piv_cac_configured
      t(
        'devise.two_factor_authentication.piv_cac_fallback.text_html',
        link: piv_cac_link
      )
    end
  end
end
