module TwoFactorAuthCode
  class PivCacAuthenticationPresenter < TwoFactorAuthCode::GenericDeliveryPresenter
    include Rails.application.routes.url_helpers
    include ActionView::Helpers::TranslationHelper

    def header
      t('two_factor_authentication.piv_cac_header_text')
    end

    def help_text
      t('instructions.mfa.piv_cac.confirm_piv_cac_html')
    end

    def piv_cac_capture_text
      t('forms.piv_cac_mfa.submit')
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
      redirect_to_piv_cac_service_url
    end

    def fallback_question
      t('two_factor_authentication.piv_cac_fallback.question')
    end

    private

    attr_reader :two_factor_authentication_method
  end
end
