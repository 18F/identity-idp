module Idv
  class GpoVerifyController < ApplicationController
    include IdvSession
    include StepIndicatorConcern
    include FraudReviewConcern

    before_action :confirm_two_factor_authenticated
    before_action :confirm_verification_needed

    def index
      analytics.idv_gpo_verification_visited
      gpo_mail = Idv::GpoMail.new(current_user)
      @mail_spammed = gpo_mail.mail_spammed?
      @gpo_verify_form = GpoVerifyForm.new(user: current_user, pii: pii)
      @code = session[:last_gpo_confirmation_code] if FeatureManagement.reveal_gpo_code?

      if throttle.throttled?
        render_throttled
      else
        render :index
      end
    end

    def pii
      Pii::Cacher.new(current_user, user_session).fetch
    end

    def create
      @gpo_verify_form = build_gpo_verify_form

      throttle.increment!
      if throttle.throttled?
        render_throttled
        return
      end

      result = @gpo_verify_form.submit
      analytics.idv_gpo_verification_submitted(**result.to_h)
      irs_attempts_api_tracker.idv_gpo_verification_submitted(
        success: result.success?,
        failure_reason: irs_attempts_api_tracker.parse_failure_reason(result),
      )

      if !result.success?
        flash[:error] = @gpo_verify_form.errors.first.message
        redirect_to idv_gpo_verify_url
        return
      end

      if result.extra[:pending_in_person_enrollment]
        redirect_to idv_in_person_ready_to_verify_url
      else
        prepare_for_personal_key

        redirect_to idv_personal_key_url
      end
    end

    private

    def prepare_for_personal_key
      event, _disavowal_token = create_user_event(:account_verified)

      if !fraud_check_failed?
        UserAlerts::AlertUserAboutAccountVerified.call(
          user: current_user,
          date_time: event.created_at,
          sp_name: decorated_session.sp_name,
        )
        flash[:success] = t('account.index.verification.success')
      end

      enable_personal_key_generation
    end

    def throttle
      @throttle ||= Throttle.new(
        user: current_user,
        throttle_type: :verify_gpo_key,
      )
    end

    def render_throttled
      irs_attempts_api_tracker.idv_gpo_verification_rate_limited
      analytics.throttler_rate_limit_triggered(
        throttle_type: :verify_gpo_key,
      )

      @expires_at = throttle.expires_at
      render :throttled
    end

    def build_gpo_verify_form
      GpoVerifyForm.new(
        user: current_user,
        pii: pii,
        otp: params_otp,
      )
    end

    def params_otp
      params.require(:gpo_verify_form).permit(:otp)[:otp]
    end

    def confirm_verification_needed
      return if current_user.pending_profile_requires_verification?
      redirect_to account_url
    end

    def fraud_check_failed?
      threatmetrix_enabled? && (current_user.fraud_review_pending? || current_user.fraud_rejection?)
    end

    def threatmetrix_enabled?
      FeatureManagement.proofing_device_profiling_decisioning_enabled?
    end

    def enable_personal_key_generation
      idv_session.resolution_successful = 'gpo'
      idv_session.applicant = pii
    end
  end
end
