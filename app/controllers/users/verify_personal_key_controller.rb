module Users
  class VerifyPersonalKeyController < ApplicationController
    include AccountReactivationConcern

    before_action :confirm_two_factor_authenticated
    before_action :confirm_password_reset_profile
    before_action :init_account_reactivation, only: [:new]

    def new
      analytics.track_event(Analytics::PERSONAL_KEY_REACTIVATION_VISITED)
      @personal_key_form = VerifyPersonalKeyForm.new(
        user: current_user,
        personal_key: '',
      )

      if Throttler::IsThrottled.call(current_user.id, :verify_personal_key)
        render_throttled
      else
        render :new
      end
    end

    def create
      throttled = Throttler::IsThrottledElseIncrement.call(
        current_user.id,
        :verify_personal_key,
      )

      if throttled
        render_throttled
      else
        result = personal_key_form.submit

        analytics.track_event(Analytics::PERSONAL_KEY_REACTIVATION_SUBMITTED, result.to_h)
        if result.success?
          handle_success(result)
        else
          handle_failure(result)
        end
      end
    end

    private

    def render_throttled
      analytics.track_event(
        Analytics::THROTTLER_RATE_LIMIT_TRIGGERED,
        throttle_type: :verify_personal_key,
      )

      render :throttled
    end

    def init_account_reactivation
      return if reactivate_account_session.started?

      flash.now[:info] = t('notices.account_reactivation')
      reactivate_account_session.start
    end

    def handle_success(result)
      analytics.track_event(Analytics::PERSONAL_KEY_REACTIVATION)
      reactivate_account_session.store_decrypted_pii(result.extra[:decrypted_pii])
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
