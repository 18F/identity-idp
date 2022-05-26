module Idv
  class GpoVerifyController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated
    before_action :confirm_verification_needed

    def index
      analytics.track_event(Analytics::IDV_GPO_VERIFICATION_VISITED)
      gpo_mail = Idv::GpoMail.new(current_user)
      @mail_spammed = gpo_mail.mail_spammed?
      @gpo_verify_form = GpoVerifyForm.new(user: current_user)
      @code = session[:last_gpo_confirmation_code] if FeatureManagement.reveal_gpo_code?

      if throttle.throttled?
        render_throttled
      else
        render :index
      end
    end

    def create
      @gpo_verify_form = build_gpo_verify_form

      if throttle.throttled_else_increment?
        render_throttled
      else
        result = @gpo_verify_form.submit
        analytics.idv_gpo_verification_submitted(**result.to_h)

        if result.success?
          event = create_user_event_with_disavowal(:account_verified)
          UserAlerts::AlertUserAboutAccountVerified.call(
            user: current_user,
            date_time: event.created_at,
            sp_name: decorated_session.sp_name,
            disavowal_token: event.disavowal_token,
          )
          flash[:success] = t('account.index.verification.success')
          redirect_to sign_up_completed_url
        else
          flash[:error] = @gpo_verify_form.errors.first.message
          redirect_to idv_gpo_verify_url
        end
      end
    end

    private

    def throttle
      @throttle ||= RedisThrottle.new(
        user: current_user,
        throttle_type: :verify_gpo_key,
      )
    end

    def render_throttled
      analytics.track_event(
        Analytics::THROTTLER_RATE_LIMIT_TRIGGERED,
        throttle_type: :verify_gpo_key,
      )

      @expires_at = throttle.expires_at
      render :throttled
    end

    def build_gpo_verify_form
      GpoVerifyForm.new(
        user: current_user,
        otp: params_otp,
      )
    end

    def params_otp
      params.require(:gpo_verify_form).permit(:otp)[:otp]
    end

    def confirm_verification_needed
      return if current_user.decorate.pending_profile_requires_verification?
      redirect_to account_url
    end
  end
end
