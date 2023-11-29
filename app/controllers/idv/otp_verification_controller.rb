module Idv
  class OtpVerificationController < ApplicationController
    include Idv::AvailabilityConcern
    include IdvSession
    include StepIndicatorConcern
    include PhoneOtpRateLimitable
    include IdvStepConcern

    before_action :confirm_two_factor_authenticated
    before_action :confirm_step_needed
    before_action :confirm_otp_sent
    before_action :set_code
    before_action :set_otp_verification_presenter

    def show
      # memoize the form so the ivar is available to the view
      phone_confirmation_otp_verification_form
      analytics.idv_phone_confirmation_otp_visit
    end

    def update
      result = phone_confirmation_otp_verification_form.submit(code: params[:code])
      analytics.idv_phone_confirmation_otp_submitted(**result.to_h, **opt_in_analytics_properties)

      irs_attempts_api_tracker.idv_phone_otp_submitted(
        success: result.success?,
        phone_number: idv_session.user_phone_confirmation_session.phone,
      )

      if result.success?
        idv_session.user_phone_confirmation = true
        save_in_person_notification_phone
        flash[:success] = t('idv.messages.enter_password.phone_verified')
        redirect_to idv_enter_password_url
      else
        handle_otp_confirmation_failure
      end
    end

    private

    def confirm_step_needed
      return unless idv_session.user_phone_confirmation
      redirect_to idv_enter_password_url
    end

    def confirm_otp_sent
      return if idv_session.user_phone_confirmation_session.present?

      redirect_to idv_phone_url
    end

    def set_code
      return unless FeatureManagement.prefill_otp_codes?
      @code = idv_session.user_phone_confirmation_session.code
    end

    def set_otp_verification_presenter
      @presenter = OtpVerificationPresenter.new(idv_session: idv_session)
    end

    def handle_otp_confirmation_failure
      if current_user.locked_out?
        handle_too_many_otp_attempts
      else
        flash.now[:error] = t('two_factor_authentication.invalid_otp')
        render :show
      end
    end

    def save_in_person_notification_phone
      return unless IdentityConfig.store.in_person_send_proofing_notifications_enabled
      return unless in_person_enrollment?
      # future tickets will support voice otp
      return unless idv_session.user_phone_confirmation_session.delivery_method == :sms

      establishing_enrollment.notification_phone_configuration =
        NotificationPhoneConfiguration.new(
          phone: idv_session.user_phone_confirmation_session.phone,
        )
    end

    def establishing_enrollment
      current_user.establishing_in_person_enrollment
    end

    def in_person_enrollment?
      return false unless IdentityConfig.store.in_person_proofing_enabled
      establishing_enrollment.present?
    end

    def phone_confirmation_otp_verification_form
      @phone_confirmation_otp_verification_form ||= PhoneConfirmationOtpVerificationForm.new(
        user: current_user,
        user_phone_confirmation_session: idv_session.user_phone_confirmation_session,
        irs_attempts_api_tracker: irs_attempts_api_tracker,
      )
    end
  end
end
