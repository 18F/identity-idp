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

      if rate_limiter.limited?
        render_rate_limited
      else
        render :new
      end
    end

    def create
      rate_limiter.increment!
      if rate_limiter.limited?
        render_rate_limited
      else
        result = personal_key_form.submit

        analytics.personal_key_reactivation_submitted(
          **result.to_h,
          pii_like_keypaths: [[:errors, :personal_key], [:error_details, :personal_key]],
        )
        irs_attempts_api_tracker.personal_key_reactivation_submitted(
          success: result.success?,
          failure_reason: irs_attempts_api_tracker.parse_failure_reason(result),
        )
        if result.success?
          handle_success(decrypted_pii: personal_key_form.decrypted_pii)
        else
          handle_failure(result)
        end
      end
    end

    private

    def rate_limiter
      @rate_limiter ||= RateLimiter.new(
        user: current_user,
        rate_limit_type: :verify_personal_key,
      )
    end

    def render_rate_limited
      analytics.rate_limit_reached(
        limiter_type: :verify_personal_key,
      )

      irs_attempts_api_tracker.personal_key_reactivation_rate_limited

      @expires_at = rate_limiter.expires_at
      render :rate_limited
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
