module SignUp
  class RecoveryCodesController < ApplicationController
    include RecoveryCodeConcern

    before_action :confirm_two_factor_authenticated
    before_action :confirm_has_not_already_viewed_recovery_code, only: [:show]

    def show
      user_session.delete(:first_time_recovery_code_view)
      @code = new_code
      analytics.track_event(Analytics::USER_REGISTRATION_RECOVERY_CODE_VISIT)
    end

    def update
      redirect_to next_step
    end

    private

    def new_code
      if session[:new_recovery_code].present?
        session.delete(:new_recovery_code)
      else
        create_new_code
      end
    end

    def confirm_has_not_already_viewed_recovery_code
      return if user_session[:first_time_recovery_code_view].present?
      redirect_to after_sign_in_path_for
    end

    def next_step
      if session[:sp]
        sign_up_completed_path
      elsif current_user.password_reset_profile.present?
        reactivate_profile_path
      else
        after_sign_in_path_for
      end
    end
  end
end
