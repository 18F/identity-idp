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
        session[:sp_email_id] = EmailContext.new(current_user).last_sign_in_email_address.id
        redirect_to sign_up_completed_path
      else
        flash[:error] = t('anonymous_mailer.password_reset_missing_user.subject')
        redirect_to sign_up_select_email_path
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
      @user_emails = current_user.confirmed_email_addresses
    end

    private

    def build_select_email_form
      SelectEmailForm.new(current_user)
    end

    def form_params
      params.fetch(:select_email_form, {}).permit(:selected_email_id)
    end
  end
end
