module TwoFactorAuthCode
  class GenericDeliveryPresenter
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::TranslationHelper

    attr_reader :code_value

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

      t("#{personal_key}.text_html", link: personal_key_tag)
    end

    private

    attr_reader :personal_key_unavailable

    def personal_key_tag
      Link.new(link_text: t("#{personal_key}.link"), path_name: 'login_two_factor_personal_key')
    end

    def personal_key
      'devise.two_factor_authentication.personal_key_fallback'
    end
  end
end
