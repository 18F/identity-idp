module Users
  class RecoveryCodesController < ApplicationController
    include RecoveryCodeConcern

    before_action :confirm_two_factor_authenticated

    def show
      @code = create_new_code
      analytics.track_event(Analytics::PROFILE_RECOVERY_CODE_CREATE)

      flash.now[:success] = t('notices.send_code.recovery_code') if params[:resend].present?
    end

    def update
      redirect_to next_step
    end

    private

    def next_step
      if current_user.password_reset_profile.present?
        reactivate_profile_url
      else
        profile_url
      end
    end
  end
end
