module Users
  class PersonalKeysController < ApplicationController
    include PersonalKeyConcern

    before_action :confirm_two_factor_authenticated

    def show
      personal_key = user_session[:personal_key]

      return redirect_to account_url if personal_key.blank?

      @code = personal_key
    end

    def update
      user_session.delete(:personal_key)
      redirect_to next_step
    end

    def create
      user_session[:personal_key] = create_new_code
      analytics.track_event(Analytics::PROFILE_PERSONAL_KEY_CREATE)
      flash[:success] = t('notices.send_code.personal_key') if params[:resend].present?
      redirect_to manage_personal_key_url
    end

    private

    def next_step
      if current_user.decorate.password_reset_profile.present?
        reactivate_account_url
      else
        account_url
      end
    end
  end
end
