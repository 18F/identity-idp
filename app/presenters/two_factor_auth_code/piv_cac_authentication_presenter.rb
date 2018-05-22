module TwoFactorAuthCode
  class PivCacAuthenticationPresenter < TwoFactorAuthCode::GenericDeliveryPresenter
    include Rails.application.routes.url_helpers
    include ActionView::Helpers::TranslationHelper

    def header
      t('devise.two_factor_authentication.piv_cac_header_text')
    end

    def help_text
      t('instructions.mfa.piv_cac.confirm_piv_cac_html',
        email: content_tag(:strong, user_email),
        app: content_tag(:strong, APP_NAME))
    end

    def piv_cac_capture_text
      t('forms.piv_cac_mfa.submit')
    end

    def fallback_links
      [
        otp_fallback_options,
        auth_app_fallback,
        personal_key_link,
      ].compact
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
      PivCacService.piv_cac_service_link(piv_cac_nonce)
    end

    private

    attr_reader :user_email, :two_factor_authentication_method, :totp_enabled, :piv_cac_nonce

    def otp_fallback_options
      t(
        'devise.two_factor_authentication.totp_fallback.text_html',
        sms_link: sms_link,
        voice_link: voice_link
      )
    end

    def sms_link
      view.link_to(
        t('devise.two_factor_authentication.totp_fallback.sms_link_text'),
        login_two_factor_path(locale: LinkLocaleResolver.locale, otp_delivery_preference: 'sms')
      )
    end

    def voice_link
      view.link_to(
        t('devise.two_factor_authentication.totp_fallback.voice_link_text'),
        login_two_factor_path(locale: LinkLocaleResolver.locale, otp_delivery_preference: 'voice')
      )
    end

    def auth_app_fallback
      safe_join([auth_app_fallback_tag, '.']) if totp_enabled
    end

    def auth_app_fallback_tag
      view.link_to(
        t('links.two_factor_authentication.app'),
        login_two_factor_authenticator_path(locale: LinkLocaleResolver.locale)
      )
    end
  end
end
