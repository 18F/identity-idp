module Users
  class VerifyAccountController < ApplicationController
    include IdvSession

    before_action :confirm_two_factor_authenticated
    before_action :confirm_verification_needed

    def index
      analytics.track_event(Analytics::ACCOUNT_VERIFICATION_VISITED)
      gpo_mail = Idv::GpoMail.new(current_user)
      @mail_spammed = gpo_mail.mail_spammed?
      @verify_account_form = VerifyAccountForm.new(user: current_user)
      @code = session[:last_gpo_confirmation_code] if FeatureManagement.reveal_gpo_code?

      if throttle.throttled?
        render_throttled
      else
        render :index
      end
    end

    def create
      @verify_account_form = build_verify_account_form

      if throttle.throttled_else_increment?
        render_throttled
      else
        result = @verify_account_form.submit
        analytics.track_event(Analytics::ACCOUNT_VERIFICATION_SUBMITTED, result.to_h)

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
          flash[:error] = @verify_account_form.errors.first.message
          redirect_to verify_account_url
        end
      end
    end

    private

    def throttle
      @throttle ||= Throttle.for(
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

    def build_verify_account_form
      VerifyAccountForm.new(
        user: current_user,
        otp: params_otp,
      )
    end

    def params_otp
      params[:verify_account_form].permit(:otp)[:otp]
    end

    def confirm_verification_needed
      return if current_user.decorate.pending_profile_requires_verification?
      redirect_to account_url
    end
  end
end
