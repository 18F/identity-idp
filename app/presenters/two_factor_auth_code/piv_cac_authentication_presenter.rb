module TwoFactorAuthCode
  class PivCacAuthenticationPresenter < TwoFactorAuthCode::GenericDeliveryPresenter
    include ActionView::Helpers::TranslationHelper

    def header
      t('two_factor_authentication.piv_cac_header_text')
    end

    def piv_cac_capture_text
      t('forms.piv_cac_mfa.submit')
    end

    def cancel_link
      if reauthn
        account_path
      else
        sign_out_path
      end
    end

    def redirect_location_step
      :piv_cac_verification
    end

    def piv_cac_service_link
      login_two_factor_piv_cac_present_piv_cac_url
    end
  end
end
