module Idv
  class OtpVerificationController < ApplicationController
    include IdvSession
    include StepIndicatorConcern
    include PhoneOtpRateLimitable

    # confirm_two_factor_authenticated before action is in PhoneOtpRateLimitable
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
      analytics.idv_phone_confirmation_otp_submitted(**result.to_h)
      irs_attempts_api_tracker.idv_phone_otp_submitted(
        success: result.success?,
        phone_number: idv_session.user_phone_confirmation_session.phone,
        failure_reason: result.success? ? {} : result.extra.slice(:code_expired, :code_matches),
      )

      if result.success?
        idv_session.user_phone_confirmation = true
        redirect_to idv_review_url
      else
        handle_otp_confirmation_failure
      end
    end

    private

    def confirm_step_needed
      return unless idv_session.user_phone_confirmation
      redirect_to idv_review_url
    end

    def confirm_otp_sent
      return if idv_session.user_phone_confirmation_session.present?

      redirect_to idv_otp_delivery_method_url
    end

    def set_code
      return unless FeatureManagement.prefill_otp_codes?
      @code = idv_session.user_phone_confirmation_session.code
    end

    def set_otp_verification_presenter
      @presenter = OtpVerificationPresenter.new(idv_session: idv_session)
    end

    def handle_otp_confirmation_failure
      if decorated_user.locked_out?
        handle_too_many_otp_attempts
      else
        flash.now[:error] = t('two_factor_authentication.invalid_otp_html', count: attempts_count_remaining)
        render :show
      end
    end

    def attempts_count_remaining
      IdentityConfig.store.login_otp_confirmation_max_attempts -
        current_user.second_factor_attempts_count
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
