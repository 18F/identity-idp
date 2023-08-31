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
      @gpo_verify_form = GpoVerifyForm.new(user: current_user, pii: pii)
      @code = session[:last_gpo_confirmation_code] if FeatureManagement.reveal_gpo_code?

      @user_can_request_another_gpo_code =
        FeatureManagement.gpo_verification_enabled? &&
        !gpo_mail.mail_spammed? &&
        !gpo_mail.profile_too_old?

      if rate_limiter.limited?
        render_rate_limited
      elsif pii_locked?
        redirect_to capture_password_url
      else
        render :index
      end
    end

    def pii
      Pii::Cacher.new(current_user, user_session).fetch
    end

    def create
      @gpo_verify_form = build_gpo_verify_form

      rate_limiter.increment!
      if rate_limiter.limited?
        render_rate_limited
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

      prepare_for_personal_key

      redirect_to idv_personal_key_url
    end

    private

    def pending_in_person_enrollment?
      return false unless IdentityConfig.store.in_person_proofing_enabled
      current_user.pending_in_person_enrollment.present?
    end

    def account_not_ready_to_be_activated?
      fraud_check_failed? || pending_in_person_enrollment?
    end

    def prepare_for_personal_key
      unless account_not_ready_to_be_activated?
        event, _disavowal_token = create_user_event(:account_verified)

        UserAlerts::AlertUserAboutAccountVerified.call(
          user: current_user,
          date_time: event.created_at,
          sp_name: decorated_session.sp_name,
        )
        flash[:success] = t('account.index.verification.success')
      end

      idv_session.address_verification_mechanism = 'gpo'
      idv_session.address_confirmed!
    end

    def rate_limiter
      @rate_limiter ||= RateLimiter.new(
        user: current_user,
        rate_limit_type: :verify_gpo_key,
      )
    end

    def render_rate_limited
      irs_attempts_api_tracker.idv_gpo_verification_rate_limited
      analytics.throttler_rate_limit_triggered(
        throttle_type: :verify_gpo_key,
      )

      @expires_at = rate_limiter.expires_at
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
      return if current_user.gpo_verification_pending_profile?
      redirect_to account_url
    end

    def threatmetrix_enabled?
      FeatureManagement.proofing_device_profiling_decisioning_enabled?
    end

    def pii_locked?
      !Pii::Cacher.new(current_user, user_session).exists_in_session?
    end
  end
end
