module SignUp
  class EmailConfirmationsController < ApplicationController
    include UnconfirmedUserConcern

    before_action :validate_request_id

    def create
      with_unconfirmed_user do
        result = EmailConfirmationTokenValidator.new(@user).submit

        analytics.track_event(Analytics::EMAIL_CONFIRMATION, result.to_h)

        if result.success?
          process_successful_confirmation
        else
          process_unsuccessful_confirmation
        end
      end
    end

    private

    def validate_request_id
      result = RequestIdValidator.new(params[:_request_id]).submit
      analytics.track_event(Analytics::EMAIL_CONFIRMATION_REQUEST_ID, result.to_h)

      return if result.success?
      flash[:error] = t('errors.messages.request_id_invalid')
      redirect_to sign_up_email_resend_url
    end

    def process_successful_confirmation
      if !@user.confirmed?
        process_valid_confirmation_token
      else
        process_confirmed_user
      end
    end

    def process_valid_confirmation_token
      @confirmation_token = params[:confirmation_token]
      flash[:notice] = t('devise.confirmations.confirmed_but_must_set_password')
      session[:user_confirmation_token] = @confirmation_token
      request_id = params.fetch(:_request_id, '')
      redirect_to sign_up_enter_password_url(
        request_id: request_id, confirmation_token: @confirmation_token
      )
    end

    def process_confirmed_user
      create_user_event(:email_changed, @user)

      flash[:notice] = t('devise.confirmations.confirmed')
      redirect_to after_confirmation_path_for(@user)
      EmailNotifier.new(@user).send_email_changed_email
    end

    def process_unsuccessful_confirmation
      return process_already_confirmed_user if @user.confirmed?

      @confirmation_token = params[:confirmation_token]
      flash[:error] = unsuccessful_confirmation_error
      redirect_to sign_up_email_resend_url(request_id: params[:_request_id])
    end

    def process_already_confirmed_user
      action_text = 'Please sign in.' unless user_signed_in?
      flash[:error] = t('devise.confirmations.already_confirmed', action: action_text)

      redirect_to user_signed_in? ? account_path : new_user_session_url
    end

    def unsuccessful_confirmation_error
      if @user.confirmation_period_expired?
        @user.decorate.confirmation_period_expired_error
      else
        t('errors.messages.confirmation_invalid_token')
      end
    end
  end
end
