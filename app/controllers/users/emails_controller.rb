module Users
  class EmailsController < ReauthnRequiredController
    before_action :confirm_two_factor_authenticated

    def edit
      @update_user_email_form = UpdateUserEmailForm.new(current_user)
    end

    def update
      @update_user_email_form = UpdateUserEmailForm.new(current_user)

      result = @update_user_email_form.submit(user_params)

      analytics.track_event(Analytics::EMAIL_CHANGE_REQUEST, result)

      if result[:success]
        process_updates
        bypass_sign_in current_user
      else
        render :edit
      end
    end

    private

    def user_params
      params.require(:update_user_email_form).permit(:email)
    end

    def process_updates
      if @update_user_email_form.email_changed?
        flash[:notice] = t('devise.registrations.email_update_needs_confirmation')
      end

      redirect_to profile_url
    end
  end
end
