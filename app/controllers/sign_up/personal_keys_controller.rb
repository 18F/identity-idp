module SignUp
  class PersonalKeysController < ApplicationController
    include PersonalKeyConcern

    before_action :confirm_user_needs_initial_personal_key, only: [:show]
    before_action :assign_initial_personal_key, only: [:show]
    before_action :confirm_two_factor_authenticated

    def show
      @code = user_session[:personal_key]
      analytics.track_event(Analytics::USER_REGISTRATION_PERSONAL_KEY_VISIT)
    end

    def update
      user_session.delete(:personal_key)
      redirect_to next_step
    end

    private

    def confirm_user_needs_initial_personal_key
      redirect_to(account_url) if user_session[:personal_key].nil? &&
                                  current_user.personal_key.present?
    end

    def assign_initial_personal_key
      user_session[:personal_key] = create_new_code if current_user.personal_key.nil?
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
