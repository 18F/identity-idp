module SignUp
  class RegistrationsController < ApplicationController
    include PhoneConfirmation
    include ApplicationHelper # for ial2_requested?

    before_action :confirm_two_factor_authenticated, only: [:destroy_confirm]
    before_action :require_no_authentication
    before_action :redirect_if_ial2_and_idv_unavailable

    CREATE_ACCOUNT = 'create_account'

    def new
      @register_user_email_form = RegisterUserEmailForm.new(
        analytics: analytics,
        attempts_tracker: irs_attempts_api_tracker,
      )
      analytics.user_registration_enter_email_visit
      render :new, formats: :html
    end

    def create
      @register_user_email_form = RegisterUserEmailForm.new(
        analytics: analytics,
        attempts_tracker: irs_attempts_api_tracker,
      )

      result = @register_user_email_form.submit(permitted_params.merge(request_id:))

      analytics.user_registration_email(**result.to_h)
      irs_attempts_api_tracker.user_registration_email_submitted(
        email: permitted_params[:email],
        success: result.success?,
        failure_reason: irs_attempts_api_tracker.parse_failure_reason(result),
      )

      if result.success?
        process_successful_creation
      else
        render :new
      end
    end

    def destroy_confirm; end

    protected

    def require_no_authentication
      return unless current_user
      redirect_to signed_in_url
    end

    def permitted_params
      params.require(:user).permit(:email, :email_language, :terms_accepted)
    end

    def process_successful_creation
      user = @register_user_email_form.user
      create_user_event(:account_created, user) unless @register_user_email_form.email_taken?

      resend_confirmation = params[:user][:resend]
      session[:email] = @register_user_email_form.email

      redirect_to sign_up_verify_email_url(resend: resend_confirmation)
    end

    def request_id
      sp_session[:request_id]
    end

    def redirect_if_ial2_and_idv_unavailable
      if ial2_requested? && !FeatureManagement.idv_available?
        redirect_to idv_unavailable_path(from: CREATE_ACCOUNT)
      end
    end
  end
end
