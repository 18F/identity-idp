module TwoFactorAuthCode
  # The WebauthnAuthenticationPresenter class is the presenter for webauthn verification
  class WebauthnAuthenticationPresenter < TwoFactorAuthCode::GenericDeliveryPresenter
    include ActionView::Helpers::TranslationHelper

    attr_reader :credential_ids, :user_opted_remember_device_cookie

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
        t('instructions.mfa.webauthn.confirm_webauthn_or_aal3_html')
      elsif service_provider_mfa_policy.phishing_resistant_required?
        t('instructions.mfa.webauthn.confirm_webauthn_only_html')
      elsif platform_authenticator?
        t('instructions.mfa.webauthn.confirm_webauthn_platform_html', app_name: APP_NAME)
      else
        t('instructions.mfa.webauthn.confirm_webauthn_html')
      end
    end

    def authenticate_button_text
      if platform_authenticator?
        t('two_factor_authentication.webauthn_platform_use_key')
      else
        t('two_factor_authentication.webauthn_use_key')
      end
    end

    def login_text
      if platform_authenticator?
        t('forms.webauthn_platform_setup.login_text')
      else
        t('forms.webauthn_setup.login_text')
      end
    end

    def help_text
      ''
    end

    def verified_info_text
      if platform_authenticator?
        t('two_factor_authentication.webauthn_platform_verified.info')
      else
        t('two_factor_authentication.webauthn_verified.info')
      end
    end

    def header
      if platform_authenticator?
        t('two_factor_authentication.webauthn_platform_header_text')
      else
        t('two_factor_authentication.webauthn_header_text')
      end
    end

    def verified_header
      if platform_authenticator?
        t('two_factor_authentication.webauthn_platform_verified.header')
      else
        t('two_factor_authentication.webauthn_verified.header')
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

    def cancel_link
      if reauthn
        account_path
      else
        sign_out_path
      end
    end

    def webauthn_not_enabled_link
      if platform_authenticator?
        login_two_factor_webauthn_error_path
      else
        login_two_factor_options_path
      end
    end

    def fallback_question
      return '' unless service_provider_mfa_policy.allow_user_to_switch_method?
      if platform_authenticator?
        t('two_factor_authentication.webauthn_platform_fallback.question')
      else
        t('two_factor_authentication.webauthn_fallback.question')
      end
    end

    def multiple_factors_enabled?
      service_provider_mfa_policy.multiple_factors_enabled?
    end

    def platform_authenticator?
      @platform_authenticator
    end
  end
end
