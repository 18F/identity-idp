module SignUp
  class PasswordsController < ApplicationController
    include UnconfirmedUserConcern

    before_action :find_user_with_confirmation_token
    before_action :confirm_user_needs_sign_up_confirmation
    before_action :stop_if_invalid_token

    def new
      password_form # Memoize the password form to use in the view
      process_successful_confirmation
    end

    def create
      result = password_form.submit(permitted_params)
      analytics.password_creation(**result.to_h)
      irs_attempts_api_tracker.user_registration_password_submitted(
        success: result.success?,
        failure_reason: result.to_h[:error_details] || result.errors.presence,
      )
      store_sp_metadata_in_session unless sp_request_id.empty?

      if result.success?
        process_successful_password_creation
      else
        process_unsuccessful_password_creation
      end
    end

    private

    def process_successful_confirmation
      process_valid_confirmation_token
      render_page
    end

    def render_page
      request_id = params.fetch(:_request_id, '')
      render(
        :new,
        locals: { request_id: request_id, confirmation_token: @confirmation_token },
        formats: :html,
      )
    end

    def permitted_params
      params.require(:password_form).permit(:confirmation_token, :password, :request_id)
    end

    def process_successful_password_creation
      password = permitted_params[:password]
      now = Time.zone.now
      UpdateUser.new(
        user: @user,
        attributes: { password: password, confirmed_at: now },
      ).call
      @user.email_addresses.take.update(confirmed_at: now)

      Funnel::Registration::AddPassword.call(@user.id)
      sign_in_and_redirect_user
    end

    def store_sp_metadata_in_session
      StoreSpMetadataInSession.new(session: session, request_id: sp_request_id).call
    end

    def password_form
      @password_form ||= PasswordForm.new(@user)
    end

    def sp_request_id
      permitted_params.fetch(:request_id, '')
    end

    def process_unsuccessful_password_creation
      @confirmation_token = params[:confirmation_token]
      @forbidden_passwords = @user.email_addresses.flat_map do |email_address|
        ForbiddenPasswords.new(email_address.email).call
      end
      render :new, locals: { request_id: sp_request_id }
    end

    def sign_in_and_redirect_user
      sign_in @user
      redirect_to authentication_methods_setup_url
    end
  end
end
