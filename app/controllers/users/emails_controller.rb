# :reek:RepeatedConditional
module Users
  # rubocop:disable Metrics/ClassLength
  class EmailsController < ReauthnRequiredController
    before_action :confirm_two_factor_authenticated
    before_action :authorize_user_to_edit_email, except: %i[add show verify resend]
    before_action :check_max_emails_per_account, only: %i[show add]

    def show
      @register_user_email_form = AddUserEmailForm.new
    end

    def add
      @register_user_email_form = AddUserEmailForm.new

      result = @register_user_email_form.submit(current_user, permitted_params)

      if result.success?
        process_successful_creation
      else
        render :show
      end
    end

    def resend
      email_address = EmailAddress.find_with_email(session_email)
      SendAddEmailConfirmation.new(current_user).call(email_address)
      flash[:success] = t('notices.resend_confirmation_email.success')
      redirect_to add_email_verify_email_url
    end

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

    def delete # rubocop:disable Metrics/AbcSize
      current_confirmed_emails = current_user.confirmed_email_addresses.map(&:email)
      result = DeleteUserEmailForm.new(current_user, email_address).submit
      analytics.track_event(Analytics::EMAIL_DELETION_REQUEST, result.to_h)
      if result.success?
        send_delete_email_notification(current_confirmed_emails)
        handle_successful_delete
      else
        flash[:error] = t('email_addresses.delete.failure')
      end

      redirect_to account_url
    end

    def verify
      if session_email.blank?
        redirect_to add_email_url
      else
        email = session_email
        @register_user_email_form = RegisterUserEmailForm.new
        @register_user_email_form.user.email = email

        render :verify, locals: { email: email }
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

    def process_successful_creation
      resend_confirmation = params[:user][:resend]
      session[:email] = @register_user_email_form.email

      redirect_to add_email_verify_email_url(resend: resend_confirmation,
                                             request_id: permitted_params[:request_id])
    end

    def session_email
      session[:email]
    end

    def permitted_params
      params.require(:user).permit(:email)
    end

    def check_max_emails_per_account
      return if EmailPolicy.new(current_user).can_add_email?
      redirect_to account_url
    end

    def send_delete_email_notification(current_confirmed_emails)
      current_confirmed_emails.each do |confirmed_email|
        UserMailer.email_deleted(confirmed_email).deliver_later
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end
