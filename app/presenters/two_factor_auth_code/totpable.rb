module TwoFactorAuthCode
  module Totpable
    def auth_app_fallback_link
      return empty unless totp_enabled

      t('links.phone_confirmation.auth_app_fallback_html', link: auth_app_fallback_tag)
    end

    private

    def empty
      '.'
    end

    def auth_app_fallback_tag
      link_to(t('links.two_factor_authentication.app'),
              login_two_factor_authenticator_path)
    end
  end
end
