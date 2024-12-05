# frozen_string_literal: true

module Users
  class EmailsController < ApplicationController
    include ReauthenticationRequiredConcern

    before_action :confirm_two_factor_authenticated
    before_action :authorize_user_to_edit_email, except: %i[add show verify resend]
    before_action :check_max_emails_per_account, only: %i[show add]
    before_action :retain_confirmed_emails, only: %i[delete]
    before_action :confirm_recently_authenticated_2fa

    def show
      session[:in_select_email_flow] = true if params[:in_select_email_flow]
      analytics.add_email_visit(in_select_email_flow: in_select_email_flow?)
      @add_user_email_form = AddUserEmailForm.new
      @pending_completions_consent = pending_completions_consent?
    end

    def add
      @add_user_email_form = AddUserEmailForm.new(in_select_email_flow: in_select_email_flow?)

      result = @add_user_email_form.submit(
        current_user, permitted_params.merge(request_id:)
      )
      analytics.add_email_request(**result)

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
      email_address = EmailAddress.where(user_id: current_user.id).find_with_email(session_email)

      if email_address && !email_address.confirmed?
        analytics.resend_add_email_request(success: true)
        SendAddEmailConfirmation.new(current_user).call(email_address:, request_id:)
        flash[:success] = t('notices.resend_confirmation_email.success')
        redirect_to add_email_verify_email_url
      else
        analytics.resend_add_email_request(success: false)
        flash[:error] = t('errors.general')
        redirect_to add_email_url
      end
    end

    def confirm_delete
      @presenter = ConfirmDeleteEmailPresenter.new(current_user, email_address)
    end

    def delete
      result = DeleteUserEmailForm.new(current_user, email_address).submit
      analytics.email_deletion_request(**result)
      if result.success?
        handle_successful_delete
      else
        flash[:error] = t('email_addresses.delete.failure')
      end

      redirect_to account_url
    end

    def pending_completions_consent?
      needs_completion_screen_reason.present?
    end

    def verify
      if session_email.blank?
        redirect_to add_email_url
      else
        render :verify,
               locals: { email: session_email, in_select_email_flow: params[:in_select_email_flow] }
      end
    end

    private

    def in_select_email_flow?
      session[:in_select_email_flow] == true
    end

    def authorize_user_to_edit_email
      return render_not_found if email_address.user != current_user
    rescue ActiveRecord::RecordNotFound
      render_not_found
    end

    def request_id
      sp_session[:request_id]
    end

    def email_address
      EmailAddress.find(params[:id])
    end

    def handle_successful_delete
      send_delete_email_notification
      user_session.delete(:selected_email_id_for_linked_identity)
      flash[:success] = t('email_addresses.delete.success')
      create_user_event(:email_deleted)
    end

    def process_successful_creation
      resend_confirmation = params[:user][:resend]
      session[:email] = @add_user_email_form.email

      redirect_to add_email_verify_email_url(
        resend: resend_confirmation,
        in_select_email_flow: session.delete(:in_select_email_flow),
      )
    end

    def session_email
      session[:email]
    end

    def permitted_params
      params.require(:user).permit(:email, :request_id)
    end

    def check_max_emails_per_account
      return if EmailPolicy.new(current_user).can_add_email?
      flash[:email_error] = t('email_addresses.add.limit')
      redirect_to account_url(anchor: 'emails')
    end

    def retain_confirmed_emails
      @current_confirmed_emails = current_user.confirmed_email_addresses.to_a
    end

    def send_delete_email_notification
      # These emails must be delivered now because the EmailAddress record will not exist
      # when run asynchronously
      @current_confirmed_emails.each do |confirmed_email|
        # rubocop:disable IdentityIdp/MailLaterLinter
        UserMailer.with(user: current_user, email_address: confirmed_email).
          email_deleted.deliver_now
        # rubocop:enable IdentityIdp/MailLaterLinter
      end
    end
  end
end
