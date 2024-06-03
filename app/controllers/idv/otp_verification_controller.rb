# frozen_string_literal: true

module Idv
  class OtpVerificationController < ApplicationController
    include Idv::AvailabilityConcern
    include IdvStepConcern
    include StepIndicatorConcern
    include PhoneOtpRateLimitable

    before_action :confirm_two_factor_authenticated
    before_action :confirm_step_allowed
    before_action :set_code
    before_action :set_otp_verification_presenter

    def show
      # memoize the form so the ivar is available to the view
      phone_confirmation_otp_verification_form
      analytics.idv_phone_confirmation_otp_visit
      @otp_code_length = code_length
    end

    def update
      clear_future_steps!
      result = phone_confirmation_otp_verification_form.submit(code: params[:code])
      analytics.idv_phone_confirmation_otp_submitted(**result.to_h, **ab_test_analytics_buckets)

      if result.success?
        idv_session.mark_phone_step_complete!
        save_in_person_notification_phone
        flash[:success] = t('idv.messages.enter_password.phone_verified')
        redirect_to idv_enter_password_url
      else
        @otp_code_length = code_length
        handle_otp_confirmation_failure
      end
    end

    def self.step_info
      Idv::StepInfo.new(
        key: :otp_verification,
        controller: self,
        next_steps: [:enter_password],
        preconditions: ->(idv_session:, user:) { idv_session.phone_otp_sent? },
        undo_step: ->(idv_session:, user:) { idv_session.user_phone_confirmation = nil },
      )
    end

    private

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
      )
    end

    def code_length
      if idv_session.user_phone_confirmation_session.delivery_method == :voice
        TwoFactorAuthenticatable::PROOFING_VOICE_DIRECT_OTP_LENGTH
      else
        TwoFactorAuthenticatable::PROOFING_SMS_DIRECT_OTP_LENGTH
      end
    end
  end
end
