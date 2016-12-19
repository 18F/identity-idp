module TwoFactorAuthCode
  class GenericDeliveryModePresenter
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::TranslationHelper

    include Rails.application.routes.url_helpers


    def initialize(data_model)
      data_model.each do |key, value|
        instance_variable_set("@#{key}", value)
        self.class.send(:attr_reader, key.to_sym)
      end
    end

    def header
      raise NotImplementedError
    end

    def help_text
      raise NotImplementedError
    end

    def authentication_fallback
      raise NotImplementedError
    end

    def fallback_options_links
      raise NotImplementedError
    end

    def recovery_code_link
      t('devise.two_factor_authentication.recovery_code_fallback.text_html', link: recovery_code_tag)
    end

    private

    def link_to(name, url, options = {})
      href = { href: url }
      content_tag(:a, name, options.merge(href))
    end

    def recovery_code_tag
      link_to(t('devise.two_factor_authentication.recovery_code_fallback.link_html'),
              login_two_factor_recovery_code_path)
    end
  end
end
