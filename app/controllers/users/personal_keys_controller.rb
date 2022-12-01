module Users
  # Handles updating a user's personal key if it used for 2FA (legacy behavior)
  class PersonalKeysController < ApplicationController
    include PersonalKeyConcern
    include SecureHeadersConcern

    before_action :confirm_two_factor_authenticated
    before_action :apply_secure_headers_override, only: :show

    def show
      personal_key = user_session[:personal_key]

      analytics.personal_key_viewed(
        personal_key_present: personal_key.present?,
      )

      return redirect_to account_url if personal_key.blank?

      @code = personal_key
    end

    def update
      user_session.delete(:personal_key)
      redirect_to next_step
    end

    private

    def next_step
      if user_needs_to_reactivate_account?
        reactivate_account_url
      elsif session[:sp] && user_has_not_visited_any_sp_yet?
        sign_up_completed_url
      else
        flash[:success] = t('account.personal_key.reset_success')
        after_sign_in_path_for(current_user)
      end
    end

    def user_has_not_visited_any_sp_yet?
      current_user.identities.consented.pluck(:last_authenticated_at).compact.empty?
    end
  end
end
