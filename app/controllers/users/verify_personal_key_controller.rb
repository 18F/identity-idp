module Users
  class VerifyPersonalKeyController < ApplicationController
    include AccountReactivationConcern

    before_action :confirm_two_factor_authenticated
    before_action :confirm_password_reset_profile
    before_action :init_account_reactivation, only: [:new]

    def new
      analytics.personal_key_reactivation_visited
      @personal_key_form = VerifyPersonalKeyForm.new(
        user: current_user,
        personal_key: '',
      )

      if throttle.throttled?
        render_throttled
      else
        render :new
      end
    end

    def create
      if throttle.throttled_else_increment?
        irs_attempts_api_tracker.personal_key_reactivation_throttled(success: false)
        render_throttled
      else
        result = personal_key_form.submit

        analytics.personal_key_reactivation_submitted(
          **result.to_h,
          pii_like_keypaths: [[:errors, :personal_key], [:error_details, :personal_key]],
        )
        irs_attempts_api_tracker.personal_key_reactivation_submitted(
          success: result.success?,
          failure_reason: result.to_h[:error_details],
        )
        if result.success?
          handle_success(decrypted_pii: personal_key_form.decrypted_pii)
        else
          handle_failure(result)
        end
      end
    end

    private

    def throttle
      @throttle ||= Throttle.new(
        user: current_user,
        throttle_type: :verify_personal_key,
      )
    end

    def render_throttled
      analytics.throttler_rate_limit_triggered(
        throttle_type: :verify_personal_key,
      )

      @expires_at = throttle.expires_at
      render :throttled
    end

    def init_account_reactivation
      return if reactivate_account_session.started?

      flash.now[:info] = t('notices.account_reactivation')
      reactivate_account_session.start
    end

    # @param [Pii::Attributes] decrypted_pii
    def handle_success(decrypted_pii:)
      analytics.personal_key_reactivation
      reactivate_account_session.store_decrypted_pii(decrypted_pii)
      redirect_to verify_password_url
    end

    def handle_failure(result)
      flash[:error] = result.errors[:personal_key].last
      redirect_to verify_personal_key_url
    end

    def personal_key_form
      VerifyPersonalKeyForm.new(
        user: current_user,
        personal_key: params.permit(:personal_key)[:personal_key],
      )
    end
  end
end
