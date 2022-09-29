module TwoFactorAuthCode
  class GenericDeliveryPresenter
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::TranslationHelper
    include Rails.application.routes.url_helpers

    attr_reader :code_value, :reauthn

    def initialize(data:, view:, service_provider:, remember_device_default: true)
      data.each do |key, value|
        instance_variable_set("@#{key}", value)
      end
      @view = view
      @service_provider = service_provider
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

    def remember_device_box_checked?
      return @remember_device_default if user_opted_remember_device_cookie.nil?
      ActiveModel::Type::Boolean.new.cast(user_opted_remember_device_cookie)
    end

    def url_options
      if @view.respond_to?(:url_options)
        @view.url_options
      else
        LinkLocaleResolver.locale_options
      end
    end

    private

    def service_provider_mfa_policy
      @service_provider_mfa_policy ||= ServiceProviderMfaPolicy.new(
        user: @view.current_user,
        service_provider: @service_provider,
        auth_method: @view.user_session[:auth_method],
        aal_level_requested: @view.sp_session[:aal_level_requested],
        piv_cac_requested: @view.sp_session[:piv_cac_requested],
        phishing_resistant_requested: @view.sp_session[:phishing_resistant_requested],
      )
    end

    attr_reader :personal_key_unavailable, :view, :user_opted_remember_device_cookie
  end
end
