module Users
  class TwoFactorAuthenticationController < ApplicationController
    include TwoFactorAuthenticatable
    include ActionView::Helpers::DateHelper

    before_action :check_remember_device_preference
    before_action :redirect_to_vendor_outage_if_phone_only, only: [:show]
    before_action :redirect_if_blank_phone, only: [:send_code]

    def show
      service_provider_mfa_requirement_redirect ||
        non_phone_redirect ||
        phone_redirect ||
        backup_code_redirect ||
        redirect_on_nothing_enabled
    end

    def send_code
      result = otp_delivery_selection_form.submit(delivery_params)
      analytics.otp_delivery_selection(**result.to_h)
      if result.success?
        handle_valid_otp_params(user_select_delivery_preference, user_selected_default_number)
        update_otp_delivery_preference_if_needed
      else
        handle_invalid_otp_delivery_preference(result)
      end
    end

    private

    def service_provider_mfa_requirement_redirect
      return unless service_provider_mfa_policy.user_needs_sp_auth_method_verification?
      redirect_to sp_required_mfa_verification_url
    end

    def non_phone_redirect
      url = redirect_url
      redirect_to url if url.present?
    end

    def phone_redirect
      return unless phone_enabled? && !VendorStatus.new.any_phone_vendor_outage?
      validate_otp_delivery_preference_and_send_code
      true
    end

    def backup_code_redirect
      return unless TwoFactorAuthentication::BackupCodePolicy.new(current_user).configured?
      redirect_to login_two_factor_backup_code_url(reauthn_params)
    end

    def redirect_on_nothing_enabled
      # "Nothing enabled" can mean one of two things:
      # 1. The user hasn't yet set up MFA, and should be redirected to setup path.
      # 2. The user has set up MFA, but none of the redirect options are currently available (e.g.
      #    vendor outage), and they should be sent to the MFA selection path.
      if MfaPolicy.new(current_user).two_factor_enabled?
        redirect_to login_two_factor_options_path
      else
        redirect_to authentication_methods_setup_url
      end
    end

    def phone_enabled?
      phone_configuration&.mfa_enabled?
    end

    def phone_configuration
      MfaContext.new(current_user).phone_configuration(user_session[:phone_id])
    end

    def validate_otp_delivery_preference_and_send_code
      result = otp_delivery_selection_form.submit(otp_delivery_preference: delivery_preference)
      analytics.otp_delivery_selection(**result.to_h)
      phone_is_confirmed = UserSessionContext.authentication_context?(context)
      phone_capabilities = PhoneNumberCapabilities.new(
        parsed_phone,
        phone_confirmed: phone_is_confirmed,
      )

      if result.success?
        handle_valid_otp_params(delivery_preference)
      elsif phone_capabilities.supports_sms?
        handle_valid_otp_params('sms')
        flash[:error] = result.errors[:phone].first
      else
        handle_invalid_otp_delivery_preference(result)
      end
    end

    def delivery_preference
      phone_configuration&.delivery_preference || current_user.otp_delivery_preference
    end

    def update_otp_delivery_preference_if_needed
      return if otp_failed_to_send?

      OtpPreferenceUpdater.new(
        user: current_user,
        preference: delivery_params[:otp_delivery_preference],
        phone_id: user_session[:phone_id],
      ).call
    end

    def otp_failed_to_send?
      return true unless user_signed_in?
      !@telephony_result&.success?
    end

    def handle_invalid_otp_delivery_preference(result)
      flash[:error] = result.errors[:phone].first
      redirect_to login_two_factor_url(otp_delivery_preference: delivery_preference)
    end

    def invalid_phone_number(telephony_error, action:)
      capture_analytics_for_exception(telephony_error)

      if action == 'show'
        redirect_to_otp_verification_with_error
      else
        flash[:error] = telephony_error.friendly_message
        redirect_back(fallback_location: account_url, allow_other_host: false)
      end
    end

    def redirect_to_otp_verification_with_error
      flash[:error] = t('errors.messages.phone_unsupported')
      redirect_to login_two_factor_url(
        otp_delivery_preference: phone_configuration.delivery_preference,
        reauthn: reauthn?,
      )
    end

    def redirect_if_blank_phone
      return if phone_to_deliver_to.present?

      flash[:error] = t('errors.messages.phone_required')
      redirect_to login_two_factor_options_path
    end

    def redirect_to_vendor_outage_if_phone_only
      return unless VendorStatus.new.all_phone_vendor_outage? &&
                    phone_enabled? &&
                    !MfaPolicy.new(current_user).multiple_factors_enabled?
      redirect_to vendor_outage_path(from: :two_factor_authentication)
    end

    def capture_analytics_for_exception(telephony_error)
      analytics.otp_phone_validation_failed(
        error: telephony_error.class.to_s,
        message: telephony_error.message,
        context: context,
        country: parsed_phone.country,
      )
    end

    def parsed_phone
      @parsed_phone ||= Phonelib.parse(phone_to_deliver_to)
    end

    def otp_delivery_selection_form
      @otp_delivery_selection_form ||= OtpDeliverySelectionForm.new(
        current_user, phone_to_deliver_to, context
      )
    end

    def reauthn_param
      otp_form = params.permit(otp_delivery_selection_form: [:reauthn])
      super || otp_form.dig(:otp_delivery_selection_form, :reauthn)
    end

    def handle_valid_otp_params(method, default = nil)
      otp_rate_limiter.reset_count_and_otp_last_sent_at if decorated_user.no_longer_locked_out?

      if exceeded_otp_send_limit?
        return handle_too_many_otp_sends(
          phone: parsed_phone.e164,
          context: context,
        )
      end
      otp_rate_limiter.increment
      if exceeded_otp_send_limit?
        return handle_too_many_otp_sends(
          phone: parsed_phone.e164,
          context: context,
        )
      end
      return handle_too_many_confirmation_sends if exceeded_phone_confirmation_limit?

      @telephony_result = send_user_otp(method)
      handle_telephony_result(method: method, default: default)
    end

    def handle_telephony_result(method:, default:)
      track_events(otp_delivery_preference: method)
      if @telephony_result.success?
        redirect_to login_two_factor_url(
          otp_delivery_preference: method,
          otp_make_default_number: default,
          reauthn: reauthn?,
        )
      elsif @telephony_result.error.is_a?(Telephony::OptOutError)
        # clear message from https://github.com/18F/identity-idp/blob/7ad3feab24f6f9e0e45224d9e9be9458c0a6a648/app/controllers/users/phones_controller.rb#L40
        flash.delete(:info)
        opt_out = PhoneNumberOptOut.mark_opted_out(phone_to_deliver_to)
        redirect_to login_two_factor_sms_opt_in_path(opt_out_uuid: opt_out)
      else
        invalid_phone_number(@telephony_result.error, action: action_name)
      end
    end

    def track_events(otp_delivery_preference:)
      analytics.telephony_otp_sent(
        area_code: parsed_phone.area_code,
        country_code: parsed_phone.country,
        phone_fingerprint: Pii::Fingerprinter.fingerprint(parsed_phone.e164),
        context: context,
        otp_delivery_preference: otp_delivery_preference,
        resend: params.dig(:otp_delivery_selection_form, :resend),
        telephony_response: @telephony_result.to_h,
        success: @telephony_result.success?,
      )

      if UserSessionContext.reauthentication_context?(context)
        irs_attempts_api_tracker.mfa_login_phone_otp_sent(
          reauthentication: true,
          phone_number: parsed_phone.e164,
          success: @telephony_result.success?,
        )
      elsif UserSessionContext.authentication_context?(context)
        irs_attempts_api_tracker.mfa_login_phone_otp_sent(
          reauthentication: false,
          phone_number: parsed_phone.e164,
          success: @telephony_result.success?,
        )
      elsif UserSessionContext.confirmation_context?(context)
        irs_attempts_api_tracker.mfa_enroll_phone_otp_sent(
          phone_number: parsed_phone.e164,
          success: @telephony_result.success?,
        )
      end
    end

    def exceeded_otp_send_limit?
      return otp_rate_limiter.lock_out_user if otp_rate_limiter.exceeded_otp_send_limit?
    end

    def phone_confirmation_throttle
      @phone_confirmation_throttle ||= Throttle.new(
        user: current_user,
        throttle_type: :phone_confirmation,
      )
    end

    def exceeded_phone_confirmation_limit?
      return false unless UserSessionContext.confirmation_context?(context)
      phone_confirmation_throttle.throttled_else_increment?
    end

    def send_user_otp(method)
      if PhoneNumberOptOut.find_with_phone(phone_to_deliver_to)
        return Telephony::Response.new(
          success: false,
          error: Telephony::OptOutError.new,
        )
      end

      current_user.create_direct_otp
      params = {
        to: phone_to_deliver_to,
        otp: current_user.direct_otp,
        expiration: TwoFactorAuthenticatable::DIRECT_OTP_VALID_FOR_MINUTES,
        channel: method.to_sym,
        domain: IdentityConfig.store.domain_name,
        country_code: parsed_phone.country,
      }

      if UserSessionContext.authentication_context?(context)
        Telephony.send_authentication_otp(**params)
      else
        Telephony.send_confirmation_otp(**params)
      end
    end

    def user_selected_default_number
      delivery_params[:otp_make_default_number]
    end

    def user_select_delivery_preference
      delivery_params[:otp_delivery_preference]
    end

    def delivery_params
      params.require(:otp_delivery_selection_form).permit(
        :otp_delivery_preference,
        :otp_make_default_number,
        :resend,
      )
    end

    def phone_to_deliver_to
      return phone_configuration&.phone if UserSessionContext.authentication_context?(context)

      user_session[:unconfirmed_phone]
    end

    def otp_rate_limiter
      @otp_rate_limiter ||= OtpRateLimiter.new(
        phone: phone_to_deliver_to,
        user: current_user,
        phone_confirmed: UserSessionContext.authentication_context?(context),
      )
    end

    def redirect_url
      if !mobile? && TwoFactorAuthentication::PivCacPolicy.new(current_user).enabled?
        login_two_factor_piv_cac_url(reauthn_params)
      elsif TwoFactorAuthentication::WebauthnPolicy.new(current_user).enabled?
        login_two_factor_webauthn_url(webauthn_params)
      elsif TwoFactorAuthentication::AuthAppPolicy.new(current_user).enabled?
        login_two_factor_authenticator_url(reauthn_params)
      end
    end

    def reauthn_params
      if reauthn?
        { reauthn: reauthn? }
      else
        {}
      end
    end

    def webauthn_params
      params = reauthn_params
      params[:platform] = current_user.webauthn_configurations.platform_authenticators.present?
      params
    end

    def handle_too_many_confirmation_sends
      flash[:error] = t(
        'errors.messages.phone_confirmation_throttled',
        timeout: distance_of_time_in_words(
          Time.zone.now,
          [phone_confirmation_throttle.expires_at, Time.zone.now].compact.max,
          except: :seconds,
        ),
      )
      if user_fully_authenticated?
        redirect_to account_url
      else
        redirect_to authentication_methods_setup_url
      end
    end
  end
end
