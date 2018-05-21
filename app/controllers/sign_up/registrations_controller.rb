module SignUp
  class RegistrationsController < ApplicationController
    include RecaptchaConcern
    include PhoneConfirmation

    before_action :confirm_two_factor_authenticated, only: [:destroy_confirm]
    before_action :require_no_authentication
    before_action :skip_session_expiration, only: [:show]

    def show
      return redirect_to sign_up_email_url if params[:request_id].blank?

      analytics.track_event(Analytics::USER_REGISTRATION_INTRO_VISIT)
    end

    def new
      @register_user_email_form = RegisterUserEmailForm.new
      analytics.track_event(Analytics::USER_REGISTRATION_ENTER_EMAIL_VISIT)
      render :new, locals: { request_id: nil }, formats: :html
    end

    def create
      @register_user_email_form = RegisterUserEmailForm.new(validate_recaptcha)

      result = @register_user_email_form.submit(permitted_params)

      analytics.track_event(Analytics::USER_REGISTRATION_EMAIL, result.to_h)

      if result.success?
        process_successful_creation
      else
        render :new, locals: { request_id: sp_request_id }
      end
    end

    def destroy_confirm; end

    protected

    def require_no_authentication
      return unless current_user
      redirect_to signed_in_url
    end

    def permitted_params
      params.require(:user).permit(:email, :request_id)
    end

    def process_successful_creation
      user = @register_user_email_form.user
      create_user_event(:account_created, user) unless @register_user_email_form.email_taken?

      resend_confirmation = params[:user][:resend]
      session[:email] = user.email

      redirect_to sign_up_verify_email_url(
        resend: resend_confirmation, request_id: permitted_params[:request_id]
      )
    end

    def sp_request_id
      request_id = permitted_params.fetch(:request_id, '')

      ServiceProviderRequest.from_uuid(request_id).uuid
    end
  end
end
