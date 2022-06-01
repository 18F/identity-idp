module SignUp
  class CancellationsController < ApplicationController
    before_action :find_user
    before_action :ensure_in_setup
    before_action :ensure_valid_confirmation_token

    def new
      properties = ParseControllerFromReferer.new(request.referer).call
      analytics.track_event(Analytics::USER_REGISTRATION_CANCELLATION, properties)
      @presenter = CancellationPresenter.new(referer: request.referer, url_options: url_options)
    end

    def destroy
      track_account_deletion_event
      url_after_cancellation = decorated_session.cancel_link_url
      destroy_user
      flash[:success] = t('sign_up.cancel.success')
      redirect_to url_after_cancellation
    end

    private

    def track_account_deletion_event
      properties = ParseControllerFromReferer.new(request.referer).call
      analytics.account_deletion(**properties)
    end

    def destroy_user
      @user&.destroy!
      sign_out if @user
    end

    def find_user
      @user = current_user
      return if current_user

      confirmation_token = session[:user_confirmation_token]
      email_address = EmailAddress.find_with_confirmation_token(confirmation_token)
      @token_validator = EmailConfirmationTokenValidator.new(email_address, current_user)
      result = @token_validator.submit

      if result.success?
        @user = email_address.user
      else
        @user = nil
      end
    end

    def ensure_in_setup
      redirect_to root_url if @user && MfaPolicy.new(@user).two_factor_enabled?
    end

    def ensure_valid_confirmation_token
      return if @user
      flash[:error] = error_message(@token_validator)
      redirect_to sign_up_email_resend_url(request_id: params[:_request_id])
    end

    def error_message(token_validator)
      if token_validator.confirmation_period_expired?
        t('errors.messages.confirmation_period_expired')
      else
        t('errors.messages.confirmation_invalid_token')
      end
    end
  end
end
