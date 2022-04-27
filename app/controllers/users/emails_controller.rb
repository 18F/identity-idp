module Users
  class EmailsController < ReauthnRequiredController
    before_action :confirm_two_factor_authenticated
    before_action :authorize_user_to_edit_email, except: %i[add show verify resend]
    before_action :check_max_emails_per_account, only: %i[show add]
    before_action :retain_confirmed_emails, only: %i[delete]

    def show
      @add_user_email_form = AddUserEmailForm.new
    end

    def add
      @add_user_email_form = AddUserEmailForm.new

      result = @add_user_email_form.submit(current_user, permitted_params)

      if result.success?
        process_successful_creation
      else
        render :show
      end
    rescue ActiveRecord::RecordNotUnique
      flash[:error] = t('email_addresses.add.duplicate')
      render :show
    end

    def resend
      email_address = EmailAddress.find_with_email(session_email)

      if email_address && !email_address.confirmed?
        SendAddEmailConfirmation.new(current_user).call(email_address)
        flash[:success] = t('notices.resend_confirmation_email.success')
        redirect_to add_email_verify_email_url
      else
        flash[:error] = t('errors.general')
        redirect_to add_email_url
      end
    end

    def confirm_delete
      @presenter = ConfirmDeleteEmailPresenter.new(current_user, email_address)
    end

    def delete
      result = DeleteUserEmailForm.new(current_user, email_address).submit
      analytics.email_deletion_request(**result.to_h)
      if result.success?
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
        render :verify, locals: { email: session_email }
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

    def handle_successful_delete
      send_delete_email_notification
      flash[:success] = t('email_addresses.delete.success')
      create_user_event(:email_deleted)
    end

    def process_successful_creation
      resend_confirmation = params[:user][:resend]
      session[:email] = @add_user_email_form.email

      redirect_to add_email_verify_email_url(
        resend: resend_confirmation,
        request_id: permitted_params[:request_id],
      )
    end

    def session_email
      session[:email]
    end

    def permitted_params
      params.require(:user).permit(:email)
    end

    def check_max_emails_per_account
      return if EmailPolicy.new(current_user).can_add_email?
      flash[:email_error] = t('email_addresses.add.limit')
      redirect_to account_url(anchor: 'emails')
    end

    def retain_confirmed_emails
      @current_confirmed_emails = current_user.confirmed_email_addresses.map(&:email)
    end

    def send_delete_email_notification
      @current_confirmed_emails.each do |confirmed_email|
        UserMailer.email_deleted(current_user, confirmed_email).deliver_now_or_later
      end
    end
  end
end
