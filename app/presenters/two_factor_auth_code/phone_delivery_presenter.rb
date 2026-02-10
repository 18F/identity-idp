# frozen_string_literal: true

module TwoFactorAuthCode
  class PhoneDeliveryPresenter < TwoFactorAuthCode::GenericDeliveryPresenter
    include ActionView::Helpers::UrlHelper
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::TranslationHelper
    include LinkHelper

    attr_reader :otp_delivery_preference,
                :otp_make_default_number,
                :unconfirmed_phone,
                :otp_expiration,
                :in_multi_mfa_selection_flow

    alias_method :unconfirmed_phone?, :unconfirmed_phone
    alias_method :in_multi_mfa_selection_flow?, :in_multi_mfa_selection_flow

    def header
      t('two_factor_authentication.header_text')
    end

    def phone_number_message
      t(
        "instructions.mfa.#{otp_delivery_preference}.code_sent_message_html",
        number_html: content_tag(:strong, phone_number),
      )
    end

    def do_not_share_code_message
      t(
        'instructions.mfa.do_not_share_code_message_html',
        app_name: APP_NAME,
        link_html: new_tab_link_to(
          t('instructions.mfa.do_not_share_code_link_text'),
          MarketingSite.help_center_article_url(
            category: 'fraud-concerns',
            article: 'overview',
          ),
        ),
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

    def alert_countdown_phases
      [
        {
          at_s: 10.minutes,
          classes: 'usa-alert--info',
          label: t('instructions.mfa.sms.minutes_remaining_html', minutes: 10),
        },
        {
          at_s: 5.minutes,
          classes: 'usa-alert--warning',
          label: t('instructions.mfa.sms.minutes_remaining_html', minutes: 5),
        },
        {
          at_s: 1.minute,
          classes: 'usa-alert--warning',
          label: t('instructions.mfa.sms.minutes_remaining_html', minutes: 1),
        },
        {
          at_s: 30,
          classes: 'usa-alert--warning',
          label: t('instructions.mfa.sms.seconds_remaining_html', seconds: 30),
        },
        {
          at_s: 0,
          classes: 'usa-alert--error',
          label: t('instructions.mfa.sms.code_expired_html'),
        },
      ]
    end

    def phone_call_text
      t('two_factor_authentication.otp_delivery_preference.phone_call')
    end

    def troubleshooting_options
      [
        troubleshoot_change_phone_or_method_option,
        BlockLinkComponent.new(
          url: MarketingSite.help_center_article_url(
            category: 'trouble-signing-in',
            article: 'authentication/issues-with-text-sms-phone-call',
          ),
          new_tab: true,
        ).with_content(t('instructions.mfa.phone_verification.issues_with_text_sms_phone_call')),
        how_add_or_change_authenticator_troubleshooting_option,
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
