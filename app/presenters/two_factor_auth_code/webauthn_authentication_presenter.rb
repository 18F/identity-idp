module TwoFactorAuthCode
  # The WebauthnAuthenticationPresenter class is the presenter for webauthn verification
  class WebauthnAuthenticationPresenter < TwoFactorAuthCode::GenericDeliveryPresenter
    include ActionView::Helpers::TranslationHelper

    attr_reader :credentials, :user_opted_remember_device_cookie

    def initialize(data:, view:, service_provider:, remember_device_default: true,
                   platform_authenticator: false)
      @platform_authenticator = platform_authenticator
      super(
        data: data,
        view: view,
        service_provider: service_provider,
        remember_device_default: remember_device_default,
      )
    end

    def webauthn_help
      if service_provider_mfa_policy.phishing_resistant_required? &&
         service_provider_mfa_policy.allow_user_to_switch_method?
        t('instructions.mfa.webauthn.confirm_webauthn_or_aal3')
      elsif service_provider_mfa_policy.phishing_resistant_required?
        t('instructions.mfa.webauthn.confirm_webauthn_only')
      elsif platform_authenticator?
        t('instructions.mfa.webauthn.confirm_webauthn_platform', app_name: APP_NAME)
      else
        t('instructions.mfa.webauthn.confirm_webauthn')
      end
    end

    def authenticate_button_text
      if platform_authenticator?
        t('two_factor_authentication.webauthn_platform_use_key')
      else
        t('two_factor_authentication.webauthn_use_key')
      end
    end

    def header
      if platform_authenticator?
        t('two_factor_authentication.webauthn_platform_header_text')
      else
        t('two_factor_authentication.webauthn_header_text')
      end
    end

    def link_text
      if service_provider_mfa_policy.phishing_resistant_required?
        if service_provider_mfa_policy.allow_user_to_switch_method?
          t('two_factor_authentication.webauthn_piv_available')
        else
          ''
        end
      else
        super
      end
    end

    def link_path
      if service_provider_mfa_policy.phishing_resistant_required?
        if service_provider_mfa_policy.allow_user_to_switch_method?
          login_two_factor_piv_cac_url
        else
          ''
        end
      else
        super
      end
    end

    def troubleshooting_options
      options = [choose_another_method_troubleshooting_option].select(&:present?)
      if platform_authenticator?
        options << BlockLinkComponent.new(
          url: help_center_redirect_path(
            category: 'trouble-signing-in',
            article: 'face-or-touch-unlock',
            flow: :two_factor_authentication,
            step: redirect_location_step,
          ),
          new_tab: true,
        ).with_content(t('instructions.mfa.webauthn_platform.learn_more_help'))
      end
      options << learn_more_about_authentication_options_troubleshooting_option
      options
    end

    def cancel_link
      if reauthn
        account_path
      else
        sign_out_path
      end
    end

    def redirect_location_step
      :webauthn_verification
    end

    def multiple_factors_enabled?
      service_provider_mfa_policy.multiple_factors_enabled?
    end

    def platform_authenticator?
      @platform_authenticator
    end
  end
end
