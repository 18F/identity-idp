module Users
  class PersonalKeysController < ApplicationController
    include PersonalKeyConcern

    before_action :confirm_two_factor_authenticated

    def show
      @code = create_new_code
      analytics.track_event(Analytics::PROFILE_PERSONAL_KEY_CREATE)

      flash.now[:success] = t('notices.send_code.personal_key') if params[:resend].present?
    end

    def update
      redirect_to next_step
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
