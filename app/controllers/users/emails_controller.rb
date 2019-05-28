module Users
  class EmailsController < ReauthnRequiredController
    before_action :confirm_two_factor_authenticated
    before_action :authorize_user_to_edit_email

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

    def confirm_delete
      @presenter = ConfirmDeleteEmailPresenter.new(current_user, email_address)
    end

    def delete
      result = DeleteUserEmailForm.new(current_user, email_address).submit
      analytics.track_event(Analytics::EMAIL_DELETION_REQUEST, result.to_h)
      if result.success?
        handle_successful_delete
      else
        flash[:error] = t('email_addresses.delete.failure')
      end

      redirect_to account_url
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

    def handle_successful_delete
      flash[:success] = t('email_addresses.delete.success')
      create_user_event(:email_deleted)
    end

    def process_updates
      if @update_user_email_form.email_changed?
        flash[:notice] = t('devise.registrations.email_update_needs_confirmation')
      end

      redirect_to account_url
    end
  end
end
