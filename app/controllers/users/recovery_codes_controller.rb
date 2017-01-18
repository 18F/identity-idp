module Users
  class RecoveryCodesController < ApplicationController
    include RecoveryCodeConcern

    before_action :confirm_two_factor_authenticated

    def show
      @code = create_new_code
      analytics.track_event(Analytics::PROFILE_RECOVERY_CODE_CREATE)

      flash[:success] = t('notices.send_code.recovery_code') if params[:resend].present?
      render '/sign_up/recovery_codes/show'
    end
  end
end
