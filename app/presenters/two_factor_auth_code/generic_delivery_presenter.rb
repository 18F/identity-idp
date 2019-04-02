module TwoFactorAuthCode
  class GenericDeliveryPresenter
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::TranslationHelper
    include Rails.application.routes.url_helpers

    attr_reader :code_value

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

    def reauthn_hidden_field_partial
      if reauthn
        'two_factor_authentication/totp_verification/reauthn'
      else
        'shared/null'
      end
    end

    private

    attr_reader :personal_key_unavailable, :view, :reauthn
  end
end
