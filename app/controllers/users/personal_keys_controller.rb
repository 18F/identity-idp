module Users
  # Handles updating a user's personal key if it used for 2FA (legacy behavior)
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
      @download_key_path = download_personal_key_path
    end

    def update
      user_session.delete(:personal_key)
      redirect_to next_step
    end

    def download
      personal_key = user_session[:personal_key]

      analytics.track_event(Analytics::PERSONAL_KEY_DOWNLOADED, success: personal_key.present?)

      if personal_key.present?
        data = personal_key + "\r\n"
        send_data data, filename: 'personal_key.txt'
      else
        head :bad_request
      end
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
      current_user.identities.pluck(:last_authenticated_at).compact.empty?
    end
  end
end
