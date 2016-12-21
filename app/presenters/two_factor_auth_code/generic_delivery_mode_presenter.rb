module TwoFactorAuthCode
  class GenericDeliveryModePresenter
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::TranslationHelper
    include Rails.application.routes.url_helpers

    attr_reader :phone_number, :code_value, :delivery_method, :reenter_phone_number_path,
                :totp_enabled, :unconfirmed_phone, :unconfirmed_user, :user_email

    def initialize(data_model)
      data_model.each do |key, value|
        instance_variable_set("@#{key}", value)
      end
    end

    def header
      raise NotImplementedError
    end

    def help_text
      raise NotImplementedError
    end

    def fallback_options_links
      raise NotImplementedError
    end

    def recovery_code_link
      return if unconfirmed_user

      t('devise.two_factor_authentication.recovery_code_fallback.text_html',
        link: recovery_code_tag)
    end

    private

    def link_to(text, url, options = {})
      href = { href: url }
      content_tag(:a, text, options.merge(href))
    end

    def recovery_code_tag
      link_to(t('devise.two_factor_authentication.recovery_code_fallback.link_html'),
              login_two_factor_recovery_code_path)
    end
  end
end
