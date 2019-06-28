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

    def step
      no_factors_enabled? ? '3' : '4'
    end

    def steps_visible?
      SignUpProgressPolicy.new(
        @view.current_user,
        @view.user_fully_authenticated?,
      ).sign_up_progress_visible?
    end

    private

    def no_factors_enabled?
      MfaPolicy.new(@view.current_user).no_factors_enabled?
    end

    attr_reader :personal_key_unavailable, :view, :reauthn
  end
end
