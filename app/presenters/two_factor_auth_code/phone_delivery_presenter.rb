module TwoFactorAuthCode
  class PhoneDeliveryPresenter < TwoFactorAuthCode::GenericDeliveryPresenter
    include ActionView::Helpers::UrlHelper
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::TranslationHelper

    attr_reader :otp_delivery_preference,
                :otp_make_default_number,
                :unconfirmed_phone,
                :otp_expiration

    alias_method :unconfirmed_phone?, :unconfirmed_phone

    def header
      t('two_factor_authentication.header_text')
    end

    def phone_number_message
      t(
        "instructions.mfa.#{otp_delivery_preference}.number_message_html",
        number: content_tag(:strong, phone_number),
        expiration: TwoFactorAuthenticatable::DIRECT_OTP_VALID_FOR_MINUTES,
      )
    end

    def landline_warning
      t(
        'two_factor_authentication.otp_delivery_preference.landline_warning_html',
        phone_setup_path: link_to(
          phone_call_text,
          phone_setup_path(otp_delivery_preference: 'voice'),
        ),
      )
    end

    def phone_call_text
      t('two_factor_authentication.otp_delivery_preference.phone_call')
    end

    def fallback_question
      t('two_factor_authentication.phone_fallback.question')
    end

    def help_text
      ''
    end

    def troubleshooting_header
      t('components.troubleshooting_options.default_heading')
    end

    def troubleshooting_options
      [
        troubleshoot_change_phone_or_method_option,
        {
          url: help_center_redirect_path(
            category: 'get-started',
            article: 'authentication-options',
            article_anchor: 'didn-t-receive-your-one-time-code',
            flow: :two_factor_authentication,
            step: :otp_confirmation,
          ),
          text: t('two_factor_authentication.phone_verification.troubleshooting.code_not_received'),
          new_tab: true,
        },
        {
          url: help_center_redirect_path(
            category: 'get-started',
            article: 'authentication-options',
            flow: :two_factor_authentication,
            step: :otp_confirmation,
          ),
          text: t('two_factor_authentication.phone_verification.troubleshooting.learn_more'),
          new_tab: true,
        },
      ]
    end

    def cancel_link
      locale = LinkLocaleResolver.locale
      if confirmation_for_add_phone || reauthn
        account_path(locale: locale)
      else
        sign_out_path(locale: locale)
      end
    end

    private

    def troubleshoot_change_phone_or_method_option
      if unconfirmed_phone
        {
          url: add_phone_path,
          text: t('two_factor_authentication.phone_verification.troubleshooting.change_number'),
        }
      else
        {
          url: login_two_factor_options_path,
          text: t('two_factor_authentication.login_options_link_text'),
        }
      end
    end

    attr_reader(
      :phone_number,
      :confirmation_for_add_phone,
    )
  end
end
