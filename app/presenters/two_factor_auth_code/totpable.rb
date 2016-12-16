module TwoFactorAuthCode
  module Totpable
    def auth_app_fallback_link(totp_enabled)
      return '.' unless totp_enabled
      t('links.phone_confirmation.auth_app_fallback', link: auth_app_fallback_tag)
    end

    private

    def auth_app_fallback_tag
      content_tag(:a,
                  t('links.two_factor_authentication.app'),
                  href: login_two_factor_authenticator_path)
    end
  end
end
