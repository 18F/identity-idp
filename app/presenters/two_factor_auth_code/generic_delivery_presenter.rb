module TwoFactorAuthCode
  class GenericDeliveryPresenter
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::TranslationHelper
    include Rails.application.routes.url_helpers

    attr_reader :phone_number, :code_value, :delivery_method, :reenter_phone_number_path,
                :totp_enabled, :unconfirmed_phone, :personal_key_unavailable, :user_email, :view

    def initialize(data_model, view = nil)
      data_model.each do |key, value|
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

      t("#{personal_key}.text_html",
        link: personal_key_tag)
    end

    private

    def link_to(text, url, options = {})
      href = { href: url }
      content_tag(:a, text, options.merge(href))
    end

    def personal_key_tag
      link_to(t("#{personal_key}.link"), login_two_factor_personal_key_path)
    end

    def personal_key
      'devise.two_factor_authentication.personal_key_fallback'
    end
  end
end
