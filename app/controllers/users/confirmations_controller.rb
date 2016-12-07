module Users
  class ConfirmationsController < Devise::ConfirmationsController
    include ValidEmailParameter

    def new
      @user = User.new
    end

    def confirm
      with_unconfirmed_user do
        result = @password_form.submit(permitted_params)

        analytics.track_event(Analytics::PASSWORD_CREATION, result)

        if result[:success]
          process_successful_password_creation
        else
          process_unsuccessful_password_creation
        end
      end
    end

    def show
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

    protected

    def with_unconfirmed_user
      token = params[:confirmation_token]

      @user = User.find_or_initialize_with_error_by(:confirmation_token, token)
      @user = User.confirm_by_token(token) if @user.confirmed?
      @password_form = PasswordForm.new(@user)

      yield
    end

    def set_view_variables
      @confirmation_token = params[:confirmation_token]
    end

    def process_successful_password_creation
      @user.confirm
      @user.update(reset_requested_at: nil, password: permitted_params[:password])
      sign_in_and_redirect_user
    end

    def process_unsuccessful_password_creation
      set_view_variables
      render :show
    end

    def process_successful_confirmation
      if !@user.confirmed?
        process_valid_confirmation_token
      else
        process_confirmed_user
      end
    end

    def process_valid_confirmation_token
      set_view_variables
      flash.now[:notice] = t('devise.confirmations.confirmed_but_must_set_password')
      render :show
    end

    def process_confirmed_user
      create_user_event(:email_changed, @user)

      flash[:notice] = t('devise.confirmations.confirmed')
      redirect_to after_confirmation_path_for(@user)
      EmailNotifier.new(@user).send_email_changed_email
    end

    def process_unsuccessful_confirmation
      return process_already_confirmed_user if @user.confirmed?

      set_view_variables

      if @user.confirmation_period_expired?
        process_expired_confirmation_token
      else
        process_invalid_confirmation_token
      end
    end

    def process_already_confirmed_user
      action_text = 'Please sign in.' unless user_signed_in?
      flash[:error] = t('devise.confirmations.already_confirmed', action: action_text)

      redirect_to user_signed_in? ? profile_path : new_user_session_url
    end

    def process_expired_confirmation_token
      flash.now[:error] = @user.decorate.confirmation_period_expired_error
      render :new
    end

    def process_invalid_confirmation_token
      flash.now[:error] = t('errors.messages.confirmation_invalid_token')
      render :new
    end

    def after_confirmation_path_for(user)
      if !user_signed_in?
        new_user_session_url
      elsif user.two_factor_enabled?
        profile_path
      else
        phone_setup_url
      end
    end

    private

    def permitted_params
      params.require(:password_form).permit(:confirmation_token, :password)
    end

    def sign_in_and_redirect_user
      sign_in @user
      redirect_to after_confirmation_path_for(@user)
    end
  end
end
