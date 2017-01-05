module SignUp
  class EmailConfirmationsController < ApplicationController
    include UnconfirmedUserConcern

    def create
      with_unconfirmed_user do
        result = EmailConfirmationTokenValidator.new(@user).submit

        analytics.track_event(Analytics::EMAIL_CONFIRMATION, result)

        if result[:success]
          process_successful_confirmation
        else
          process_unsuccessful_confirmation
        end
      end
    end

    private

    def process_successful_confirmation
      if !@user.confirmed?
        process_valid_confirmation_token
      else
        process_confirmed_user
      end
    end

    def process_valid_confirmation_token
      @confirmation_token = params[:confirmation_token]
      flash.now[:notice] = t('devise.confirmations.confirmed_but_must_set_password')
      render '/sign_up/passwords/new'
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
      redirect_to sign_up_email_resend_path
    end

    def process_already_confirmed_user
      action_text = 'Please sign in.' unless user_signed_in?
      flash[:error] = t('devise.confirmations.already_confirmed', action: action_text)

      redirect_to user_signed_in? ? profile_path : new_user_session_url
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
