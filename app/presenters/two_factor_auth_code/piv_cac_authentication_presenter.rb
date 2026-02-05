# frozen_string_literal: true

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

    def issues_with_piv_cac_troubleshooting_option
      BlockLinkComponent.new(
        url: MarketingSite.help_center_article_url(
          category: 'trouble-signing-in',
          article: 'authentication/issues-with-government-employee-id-piv-cac',
        ),
        new_tab: true,
      ).with_content(t('instructions.mfa.piv_cac.issues_with_piv_cac'))
    end

    def troubleshooting_options
      [
        choose_another_method_troubleshooting_option,
        issues_with_piv_cac_troubleshooting_option,
        how_add_or_change_authenticator_troubleshooting_option,
      ]
    end
  end
end
