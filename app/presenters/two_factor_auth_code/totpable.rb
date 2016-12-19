module TwoFactorAuthCode
  module Totpable
    def auth_app_fallback_link
      t('links.phone_confirmation.auth_app_fallback_html', link: auth_app_fallback_tag)
    end

    def empty
      '.'
    end

    private

    def auth_app_fallback_tag
      link_to(t('links.two_factor_authentication.app_html'),
              login_two_factor_authenticator_path)
    end
  end
end
