module TwoFactorAuthCode
  class PivCacAuthenticationPresenter < TwoFactorAuthCode::GenericDeliveryPresenter
    include ActionView::Helpers::TranslationHelper

    def header
      t('two_factor_authentication.piv_cac_header_text')
    end

    def piv_cac_help
      if service_provider_mfa_policy.phishing_resistant_required? &&
         service_provider_mfa_policy.allow_user_to_switch_method?
        t('instructions.mfa.piv_cac.confirm_piv_cac_or_aal3_html')
      elsif service_provider_mfa_policy.phishing_resistant_required? ||
            service_provider_mfa_policy.piv_cac_required?
        t('instructions.mfa.piv_cac.confirm_piv_cac_only_html')
      else
        t('instructions.mfa.piv_cac.confirm_piv_cac_html')
      end
    end

    def help_text
      ''
    end

    def piv_cac_capture_text
      t('forms.piv_cac_mfa.submit')
    end

    def link_text
      if service_provider_mfa_policy.phishing_resistant_required?
        if service_provider_mfa_policy.allow_user_to_switch_method?
          t('two_factor_authentication.piv_cac_webauthn_available')
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
          login_two_factor_webauthn_url
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

    def piv_cac_service_link
      login_two_factor_piv_cac_present_piv_cac_url
    end

    def fallback_question
      return if @hide_fallback_question
      if service_provider_mfa_policy.allow_user_to_switch_method?
        t('two_factor_authentication.piv_cac_fallback.question')
      else
        ''
      end
    end

    private

    attr_reader :two_factor_authentication_method
  end
end
