module TwoFactorAuthCode
  class PivCacAuthenticationPresenter < TwoFactorAuthCode::GenericDeliveryPresenter
    include Rails.application.routes.url_helpers
    include ActionView::Helpers::TranslationHelper

    def header
      t('two_factor_authentication.piv_cac_header_text')
    end

    def help_text
      if aal3_policy.aal3_required? && !aal3_policy.multiple_aal3_configurations?
        t('instructions.mfa.piv_cac.confirm_piv_cac_only_html')
      else
        t('instructions.mfa.piv_cac.confirm_piv_cac_html')
      end
    end

    def piv_cac_capture_text
      t('forms.piv_cac_mfa.submit')
    end

    def link_text
      if aal3_policy.aal3_required?
        if aal3_policy.multiple_aal3_configurations?
          t('two_factor_authentication.piv_cac_webauthn_available')
        else
          ''
        end
      else
        super
      end
    end

    def link_path
      if aal3_policy.aal3_required?
        if aal3_policy.multiple_aal3_configurations?
          login_two_factor_webauthn_url
        else
          ''
        end
      else
        super
      end
    end

    def cancel_link
      locale = LinkLocaleResolver.locale
      if reauthn
        account_path(locale: locale)
      else
        sign_out_path(locale: locale)
      end
    end

    def piv_cac_service_link
      login_two_factor_piv_cac_present_piv_cac_url
    end

    def fallback_question
      return if @hide_fallback_question
      if aal3_policy.aal3_required? && !aal3_policy.multiple_aal3_configurations?
        ''
      else
        t('two_factor_authentication.piv_cac_fallback.question')
      end
    end

    private

    attr_reader :two_factor_authentication_method
  end
end
