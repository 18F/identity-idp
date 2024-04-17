# frozen_string_literal: true

module Users
  class PhoneSetupController < ApplicationController
    include TwoFactorAuthenticatableMethods
    include UserAuthenticator
    include MfaSetupConcern
    include RecaptchaConcern
    include ReauthenticationRequiredConcern

    before_action :authenticate_user
    before_action :confirm_user_authenticated_for_2fa_setup
    before_action :set_setup_presenter
    before_action :allow_csp_recaptcha_src, if: :recaptcha_enabled?
    before_action :redirect_if_phone_vendor_outage
    before_action :confirm_recently_authenticated_2fa
    before_action :check_max_phone_numbers_per_account, only: %i[index create]

    helper_method :in_multi_mfa_selection_flow?

    def index
      user_session[:phone_id] = nil
      @new_phone_form = NewPhoneForm.new(
        user: current_user,
        analytics: analytics,
        setup_voice_preference: setup_voice_preference?,
      )
      track_phone_setup_visit
    end

    def create
      @new_phone_form = NewPhoneForm.new(user: current_user, analytics: analytics)
      result = @new_phone_form.submit(new_phone_form_params)
      analytics.multi_factor_auth_phone_setup(**result.to_h)

      if result.success?
        handle_create_success(@new_phone_form.phone)
      elsif recoverable_recaptcha_error?(result) && !failed_spam_protection_challenge?
        render :spam_protection
      else
        flash.now[:error] = result.first_error_message
        render :index
      end
    end

    private

    def recaptcha_enabled?
      FeatureManagement.phone_recaptcha_enabled?
    end

    def failed_spam_protection_challenge?
      new_phone_form_params[:recaptcha_version].to_s == '2'
    end

    def track_phone_setup_visit
      mfa_user = MfaContext.new(current_user)
      if user_session[:in_account_creation_flow]
        analytics.user_registration_phone_setup_visit(
          enabled_mfa_methods_count: mfa_user.enabled_mfa_methods_count,
        )
      else
        analytics.add_phone_setup_visit
      end
    end

    def set_setup_presenter
      @presenter = SetupPresenter.new(
        current_user: current_user,
        user_fully_authenticated: user_fully_authenticated?,
        user_opted_remember_device_cookie: user_opted_remember_device_cookie,
        remember_device_default: remember_device_default,
      )
    end

    def setup_voice_preference?
      params[:otp_delivery_preference].to_s == 'voice'
    end

    def handle_create_success(phone)
      if MfaContext.new(current_user).phone_configurations.map(&:phone).index(phone).nil?
        prompt_to_confirm_phone(
          id: nil,
          phone: @new_phone_form.phone,
          selected_delivery_method: @new_phone_form.otp_delivery_preference,
          phone_type: @new_phone_form.phone_info&.type,
          selected_default_number: @new_phone_form.otp_make_default_number,
        )
      else
        flash[:error] = t('errors.messages.phone_duplicate')
        redirect_to phone_setup_url
      end
    end

    def prompt_to_confirm_phone(id:, phone:, selected_delivery_method: nil,
                                selected_default_number: nil, phone_type: nil)

      user_session[:unconfirmed_phone] = phone
      user_session[:context] = 'confirmation'
      user_session[:phone_type] = phone_type.to_s

      redirect_to otp_send_url(
        otp_delivery_selection_form: {
          otp_delivery_preference: otp_delivery_method(id, phone, selected_delivery_method),
          otp_make_default_number: selected_default_number,
        },
      )
    end

    def otp_delivery_method(_id, phone, selected_delivery_method)
      capabilities = PhoneNumberCapabilities.new(phone, phone_confirmed: false)
      return :sms if capabilities.sms_only?
      return selected_delivery_method if selected_delivery_method.present?
      current_user.otp_delivery_preference
    end

    def check_max_phone_numbers_per_account
      max_phones_count = IdentityConfig.store.max_phone_numbers_per_account
      return if current_user.phone_configurations.count < max_phones_count
      flash[:phone_error] = t('users.phones.error_message')
      redirect_path = request.referer.match(account_two_factor_authentication_url) ?
                        account_two_factor_authentication_url(anchor: 'phones') :
                        account_url(anchor: 'phones')
      redirect_to redirect_path
    end

    def redirect_if_phone_vendor_outage
      return unless OutageStatus.new.all_phone_vendor_outage?
      redirect_to vendor_outage_path(from: :users_phones)
    end

    def new_phone_form_params
      params.require(:new_phone_form).permit(
        :phone,
        :international_code,
        :otp_delivery_preference,
        :otp_make_default_number,
        :recaptcha_token,
        :recaptcha_version,
        :recaptcha_mock_score,
      )
    end
  end
end
