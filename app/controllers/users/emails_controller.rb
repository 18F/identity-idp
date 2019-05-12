module Users
  class EmailsController < ReauthnRequiredController
    before_action :confirm_two_factor_authenticated
    before_action :authorize_user_to_edit_email

    def add; end

    def create; end

    def edit
      @update_user_email_form = UpdateUserEmailForm.new(current_user, email_address)
    end

    def update
      @update_user_email_form = UpdateUserEmailForm.new(current_user, email_address)

      result = @update_user_email_form.submit(user_params)

      analytics.track_event(Analytics::EMAIL_CHANGE_REQUEST, result.to_h)

      if result.success?
        process_updates
        bypass_sign_in current_user
      else
        render :edit
      end
    end

    private

    def authorize_user_to_edit_email
      return render_not_found if email_address.user != current_user
    rescue ActiveRecord::RecordNotFound
      render_not_found
    end

    def email_address
      EmailAddress.find(params[:id])
    end

    def user_params
      params.require(:update_user_email_form).permit(:email)
    end

    def process_updates
      if @update_user_email_form.email_changed?
        flash[:notice] = t('devise.registrations.email_update_needs_confirmation')
      end

      redirect_to account_url
    end
  end
end
