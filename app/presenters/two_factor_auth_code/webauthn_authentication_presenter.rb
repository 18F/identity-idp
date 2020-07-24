module TwoFactorAuthCode
  # The WebauthnAuthenticationPresenter class is the presenter for webauthn verification
  class WebauthnAuthenticationPresenter < TwoFactorAuthCode::GenericDeliveryPresenter
    include Rails.application.routes.url_helpers
    include ActionView::Helpers::TranslationHelper

    attr_reader :credential_ids, :user_opted_remember_device_cookie

    def webauthn_help
      if aal3_policy.aal3_required? && !aal3_policy.multiple_aal3_configurations?
        t('instructions.mfa.webauthn.confirm_webauthn_only_html')
      else
        t('instructions.mfa.webauthn.confirm_webauthn_html')
      end
    end

    def help_text
      ''
    end

    def header
      ''
    end

    def link_text
      if aal3_policy.aal3_required?
        if aal3_policy.multiple_aal3_configurations?
          t('two_factor_authentication.webauthn_piv_available')
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
          login_two_factor_piv_cac_url
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

    def fallback_question
      if aal3_policy.aal3_required? && !aal3_policy.multiple_aal3_configurations?
        ''
      else
        t('two_factor_authentication.webauthn_fallback.question')
      end
    end
  end
end
