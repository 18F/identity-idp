module Users
  class PersonalKeysController < ApplicationController
    include PersonalKeyConcern
    include SecureHeadersConcern

    before_action :confirm_two_factor_authenticated
    before_action :apply_secure_headers_override, only: :show

    def show
      personal_key = user_session[:personal_key]

      analytics.track_event(
        Analytics::PERSONAL_KEY_VIEWED, personal_key_present: personal_key.present?
      )

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
      elsif session[:sp] && user_has_not_visited_any_sp_yet?
        sign_up_completed_url
      else
        after_sign_in_path_for(current_user)
      end
    end

    def user_has_not_visited_any_sp_yet?
      current_user.identities.pluck(:last_authenticated_at).compact.empty?
    end
  end
end
