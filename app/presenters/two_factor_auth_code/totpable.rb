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
      sr_only = content_tag(:span, t('links.two_factor_authentication.app_sr_only'), class: 'hide')

      link_to(
        t('links.two_factor_authentication.app_html', sr_only: sr_only),
        login_two_factor_authenticator_path
      )
    end
  end
end
