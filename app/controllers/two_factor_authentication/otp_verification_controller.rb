module TwoFactorAuthentication
  class OtpVerificationController < ApplicationController
    include TwoFactorAuthenticatable
    include MfaSetupConcern

    before_action :check_sp_required_mfa
    before_action :confirm_multiple_factors_enabled
    before_action :redirect_if_blank_phone, only: [:show]
    before_action :confirm_voice_capability, only: [:show]

    def show
      analytics.multi_factor_auth_enter_otp_visit(**analytics_properties)

      @landline_alert = landline_warning?
      @presenter = presenter_for_two_factor_authentication_method
    end

    def create
      result = otp_verification_form.submit
      post_analytics(result)
      if result.success?
        handle_remember_device_preference(params[:remember_device])

        if UserSessionContext.confirmation_context?(context)
          handle_valid_confirmation_otp
        else
          handle_valid_verification_for_authentication_context(
            auth_method: params[:otp_delivery_preference],
          )
          redirect_to after_sign_in_path_for(current_user)
        end

        reset_otp_session_data
      else
        handle_invalid_otp(context: context, type: 'otp')
      end
    end

    private

    def handle_valid_confirmation_otp
      assign_phone
      track_mfa_added
      handle_valid_verification_for_confirmation_context(
        auth_method: params[:otp_delivery_preference],
      )
      flash[:success] = t('notices.phone_confirmed')
      user_session.delete(:in_account_creation_flow)
      redirect_to next_setup_path || after_mfa_setup_path
    end

    def otp_verification_form
      OtpVerificationForm.new(current_user, sanitized_otp_code, phone_configuration)
    end

    def redirect_if_blank_phone
      return if phone.present?

      flash[:error] = t('errors.messages.phone_required')
      redirect_to new_user_session_path
    end

    def track_mfa_added
      analytics.multi_factor_auth_added_phone(
        enabled_mfa_methods_count: MfaContext.new(current_user).enabled_mfa_methods_count,
      )
      Funnel::Registration::AddMfa.call(current_user.id, 'phone', analytics)
    end

    def confirm_multiple_factors_enabled
      return if UserSessionContext.confirmation_context?(context)
      phone_enabled = phone_enabled?
      return if phone_enabled

      if MfaPolicy.new(current_user).two_factor_enabled? &&
         !phone_enabled && user_signed_in?
        return redirect_to user_two_factor_authentication_url
      end

      redirect_to phone_setup_url
    end

    def phone_enabled?
      TwoFactorAuthentication::PhonePolicy.new(current_user).enabled?
    end

    def landline_warning?
      user_session[:phone_type] == 'landline' && params[:otp_delivery_preference] == 'sms'
    end

    def confirm_voice_capability
      return if params[:otp_delivery_preference] == 'sms'

      phone_is_confirmed = UserSessionContext.authentication_or_reauthentication_context?(context)

      capabilities = PhoneNumberCapabilities.new(phone, phone_confirmed: phone_is_confirmed)

      return if capabilities.supports_voice?

      flash[:error] = t(
        'two_factor_authentication.otp_delivery_preference.voice_unsupported',
        location: capabilities.unsupported_location,
      )
      redirect_to login_two_factor_url(otp_delivery_preference: 'sms')
    end

    def phone
      phone_configuration&.phone ||
        user_session[:unconfirmed_phone]
    end

    def phone_configuration
      return @phone_configuration if defined?(@phone_configuration)
      @phone_configuration =
        MfaContext.new(current_user).phone_configuration(user_session[:phone_id])
    end

    def sanitized_otp_code
      form_params[:code].to_s.strip.sub(/^#/, '')
    end

    def form_params
      params.permit(:code)
    end

    def post_analytics(result)
      properties = result.to_h.merge(analytics_properties)
      analytics.multi_factor_auth_setup(**properties) if context == 'confirmation'

      analytics.track_mfa_submit_event(properties)

      if UserSessionContext.reauthentication_context?(context)
        irs_attempts_api_tracker.mfa_login_phone_otp_submitted(
          reauthentication: true,
          success: properties[:success],
        )
      elsif UserSessionContext.authentication_or_reauthentication_context?(context)
        irs_attempts_api_tracker.mfa_login_phone_otp_submitted(
          reauthentication: false,
          success: properties[:success],
        )
      elsif UserSessionContext.confirmation_context?(context)
        irs_attempts_api_tracker.mfa_enroll_phone_otp_submitted(
          success: properties[:success],
        )
      end
    end

    def analytics_properties
      parsed_phone = Phonelib.parse(phone)

      {
        context: context,
        multi_factor_auth_method: params[:otp_delivery_preference],
        confirmation_for_add_phone: confirmation_for_add_phone?,
        area_code: parsed_phone.area_code,
        country_code: parsed_phone.country,
        phone_fingerprint: Pii::Fingerprinter.fingerprint(parsed_phone.e164),
        phone_configuration_id: phone_configuration&.id,
        in_account_creation_flow: user_session[:in_account_creation_flow] || false,
        enabled_mfa_methods_count: mfa_context.enabled_mfa_methods_count,
      }
    end

    def presenter_for_two_factor_authentication_method
      TwoFactorAuthCode::PhoneDeliveryPresenter.new(
        data: phone_view_data,
        view: view_context,
        service_provider: current_sp,
        remember_device_default: remember_device_default,
      )
    end

    def phone_view_data
      {
        confirmation_for_add_phone: confirmation_for_add_phone?,
        phone_number: display_phone_to_deliver_to,
        code_value: direct_otp_code,
        otp_expiration: otp_expiration,
        otp_delivery_preference: params[:otp_delivery_preference],
        otp_make_default_number: selected_otp_make_default_number,
        unconfirmed_phone: unconfirmed_phone?,
      }.merge(generic_data)
    end

    def display_phone_to_deliver_to
      if UserSessionContext.authentication_or_reauthentication_context?(context)
        phone_configuration.masked_phone
      else
        user_session[:unconfirmed_phone]
      end
    end

    def unconfirmed_phone?
      user_session[:unconfirmed_phone] && UserSessionContext.confirmation_context?(context)
    end

    def confirmation_for_add_phone?
      UserSessionContext.confirmation_context?(context) && user_fully_authenticated?
    end

    def check_sp_required_mfa
      check_sp_required_mfa_bypass(auth_method: params[:otp_delivery_preference])
    end

    def assign_phone
      if updating_existing_number?
        phone_changed
      else
        phone_confirmed
      end

      update_phone_attributes
    end

    def updating_existing_number?
      user_session[:phone_id].present?
    end

    def update_phone_attributes
      UpdateUser.new(
        user: current_user,
        attributes: { phone_id: user_session[:phone_id],
                      phone: user_session[:unconfirmed_phone],
                      phone_confirmed_at: Time.zone.now,
                      otp_make_default_number: selected_otp_make_default_number },
      ).call
    end

    def phone_changed
      create_user_event(:phone_changed)
      send_phone_added_email
    end

    def phone_confirmed
      create_user_event(:phone_confirmed)
      # If the user has MFA configured, then they are not adding a phone during sign up and are
      # instead adding it outside the sign up flow
      return unless MfaPolicy.new(current_user).two_factor_enabled?
      send_phone_added_email
    end

    def send_phone_added_email
      _event, disavowal_token = create_user_event_with_disavowal(:phone_added, current_user)
      current_user.confirmed_email_addresses.each do |email_address|
        UserMailer.with(user: current_user, email_address: email_address).
          phone_added(disavowal_token: disavowal_token).deliver_now_or_later
      end
    end

    def selected_otp_make_default_number
      params&.dig(:otp_make_default_number)
    end

    def direct_otp_code
      current_user.direct_otp if FeatureManagement.prefill_otp_codes?
    end

    def reset_otp_session_data
      user_session.delete(:unconfirmed_phone)
      user_session[:context] = 'authentication'
    end
  end
end
