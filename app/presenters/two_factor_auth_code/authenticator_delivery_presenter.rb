# frozen_string_literal: true

module TwoFactorAuthCode
  class AuthenticatorDeliveryPresenter < TwoFactorAuthCode::GenericDeliveryPresenter
    def header
      t('two_factor_authentication.totp_header_text')
    end

    def cancel_link
      if reauthn
        account_path
      else
        sign_out_path
      end
    end

    def redirect_location_step
      :totp_verification
    end


    def troubleshooting_options
      [
        choose_another_method_troubleshooting_option,
        BlockLinkComponent.new(
          url: MarketingSite.help_center_article_url(
            category: 'trouble-signing-in',
            article: 'authentication/issues-with-authentication-application',
          ),
          new_tab: true,
        ).with_content(t('instructions.mfa.authenticator.issues_with_authenticator')),
        how_add_or_change_authenticator_troubleshooting_option,
      ]
    end
  end
end
