module Users
  class EditEmailController < ReauthnRequiredController
    before_action :confirm_two_factor_authenticated

    def edit
      @update_user_email_form = UpdateUserEmailForm.new(current_user)
    end

    def update
      @update_user_email_form = UpdateUserEmailForm.new(current_user)

      if @update_user_email_form.submit(user_params)
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
        track_email_change
        flash[:notice] = t('devise.registrations.email_update_needs_confirmation')
      end

      redirect_to profile_url
    end

    def track_email_change
      if @update_user_email_form.email_taken?
        analytics.track_event('User attempted to change their email to an existing email')
      else
        analytics.track_event('User asked to change their email')
      end
    end
  end
end
