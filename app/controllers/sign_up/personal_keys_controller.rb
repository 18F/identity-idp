module SignUp
  class PersonalKeysController < ApplicationController
    include PersonalKeyConcern

    before_action :confirm_two_factor_authenticated
    before_action :confirm_has_not_already_viewed_personal_key, only: [:show]

    def show
      user_session.delete(:first_time_personal_key_view)
      @code = new_code
      analytics.track_event(Analytics::USER_REGISTRATION_PERSONAL_KEY_VISIT)
    end

    def update
      redirect_to next_step
    end

    private

    def new_code
      if session[:new_personal_key].present?
        session.delete(:new_personal_key)
      else
        create_new_code
      end
    end

    def confirm_has_not_already_viewed_personal_key
      return if user_session[:first_time_personal_key_view].present?
      redirect_to after_sign_in_path_for(current_user)
    end

    def next_step
      if session[:sp]
        sign_up_completed_url
      elsif current_user.decorate.password_reset_profile.present?
        reactivate_account_url
      else
        after_sign_in_path_for(current_user)
      end
    end
  end
end
