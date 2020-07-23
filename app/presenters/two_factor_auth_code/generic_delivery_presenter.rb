module TwoFactorAuthCode
  class GenericDeliveryPresenter
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::TranslationHelper
    include Rails.application.routes.url_helpers

    attr_reader :code_value

    def initialize(data:, view:, remember_device_default: true)
      data.each do |key, value|
        instance_variable_set("@#{key}", value)
      end
      @view = view
      @remember_device_default = remember_device_default
    end

    def header
      raise NotImplementedError
    end

    def help_text
      raise NotImplementedError
    end

    def link_text
      t('two_factor_authentication.login_options_link_text')
    end

    def link_path
      login_two_factor_options_path
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

    def remember_device_box_checked?
      return @remember_device_default if user_opted_remember_device_cookie.nil?
      ActiveModel::Type::Boolean.new.cast(user_opted_remember_device_cookie)
    end

    private

    def aal3_policy
      @aal3 ||= AAL3Policy.new(session: @view.session, user: @view.current_user)
    end

    def no_factors_enabled?
      MfaPolicy.new(@view.current_user).no_factors_enabled?
    end

    attr_reader :personal_key_unavailable, :view, :reauthn, :user_opted_remember_device_cookie
  end
end
