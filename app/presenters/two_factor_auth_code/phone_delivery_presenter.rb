module TwoFactorAuthCode
  class PhoneDeliveryPresenter < TwoFactorAuthCode::GenericDeliveryPresenter
    include ActionView::Helpers::UrlHelper
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::TranslationHelper

    attr_reader :otp_delivery_preference,
                :otp_make_default_number,
                :unconfirmed_phone,
                :otp_expiration,
                :in_multi_mfa_selection_flow,
                :data

    alias_method :unconfirmed_phone?, :unconfirmed_phone
    alias_method :in_multi_mfa_selection_flow?, :in_multi_mfa_selection_flow

    def header
      t('two_factor_authentication.header_text')
    end

    def phone_number_message
      t(
        "instructions.mfa.#{otp_delivery_preference}.number_message_html",
        number_html: content_tag(:strong, phone_number),
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

    def troubleshooting_options
      [
        troubleshoot_change_phone_or_method_option,
        BlockLinkComponent.new(
          url: help_center_redirect_path(
            category: 'get-started',
            article: 'authentication-options',
            article_anchor: 'didn-t-receive-your-one-time-code',
            flow: :two_factor_authentication,
            step: :otp_confirmation,
          ),
          new_tab: true,
        ).with_content(
          t('two_factor_authentication.phone_verification.troubleshooting.code_not_received'),
        ),
        learn_more_about_authentication_options_troubleshooting_option,
      ]
    end

    def cancel_link
      locale = LinkLocaleResolver.locale
      if in_multi_mfa_selection_flow
        authentication_methods_setup_path(locale: locale)
      elsif confirmation_for_add_phone || reauthn
        account_path(locale: locale)
      else
        sign_out_path(locale: locale)
      end
    end

    def redirect_location_step
      :otp_confirmation
    end

    private

    def troubleshoot_change_phone_or_method_option
      if unconfirmed_phone
        BlockLinkComponent.new(url: phone_setup_path).with_content(
          t('two_factor_authentication.phone_verification.troubleshooting.change_number'),
        )
      else
        BlockLinkComponent.new(url: login_two_factor_options_path).with_content(
          t('two_factor_authentication.login_options_link_text'),
        )
      end
    end

    attr_reader(
      :phone_number,
      :confirmation_for_add_phone,
    )
  end
end
