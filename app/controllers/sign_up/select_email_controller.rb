# frozen_string_literal: true

module SignUp
  class SelectEmailController < ApplicationController
    before_action :confirm_two_factor_authenticated

    def show
      @sp_name = sp_name
      @user_emails = user_emails
      @last_sign_in_email_address = EmailContext.new(current_user).last_sign_in_email_address.email
      @select_email_form = build_select_email_form
    end

    def create
      @select_email_form = build_select_email_form

      result = @select_email_form.submit(form_params)
      if result.success?

        EmailAddress.update_last_sign_in_at_on_user_id_and_email(
          user_id: current_user.id,
          email: form_params[:selection],
        )

        session[:sp_email_id] = EmailContext.new(current_user).last_sign_in_email_address.id
        redirect_to sign_up_completed_path
      else
        render :show
      end
    end

    def sp_name
      if current_sp
        @sp_name ||= current_sp.friendly_name || sp.agency&.name
      else
        @sp_name = APP_NAME
      end
    end

    def user_emails
      @user_emails = current_user.email_addresses.map { |e| e.email }
    end

    private

    def build_select_email_form
      SelectEmailForm.new(current_user)
    end

    def form_params
      params.fetch(:select_email_form, {}).permit(:selection)
    end
  end
end
