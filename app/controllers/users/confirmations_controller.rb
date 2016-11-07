module Users
  class ConfirmationsController < Devise::ConfirmationsController
    include ValidEmailParameter

    def confirm
      with_unconfirmed_confirmable do
        if @password_form.submit(permitted_params)
          do_confirm
        else
          process_user_with_password_errors
        end
      end
    end

    def show
      with_unconfirmed_confirmable do
        return process_user_with_confirmation_errors if @confirmable.errors.present?

        if !@confirmable.confirmed?
          process_unconfirmed_user
        else
          process_confirmed_user
        end
      end
    end

    protected

    def with_unconfirmed_confirmable
      token = params[:confirmation_token]

      @confirmable = User.find_or_initialize_with_error_by(:confirmation_token, token)
      @confirmable = User.confirm_by_token(token) if @confirmable.confirmed?

      @password_form = PasswordForm.new(@confirmable)

      yield
    end

    def set_view_variables
      @confirmation_token = params[:confirmation_token]
      self.resource = @confirmable
    end

    def do_confirm
      @confirmable.confirm
      @confirmable.update(reset_requested_at: nil)
      sign_in_and_redirect_user
      analytics.track_event(Analytics::PASSWORD_CREATE_USER_CONFIRMED)
    end

    def process_user_with_password_errors
      analytics.track_event(Analytics::PASSWORD_CREATE_INVALID, user_id: @confirmable.uuid)

      set_view_variables
      render :show
    end

    def process_user_with_confirmation_errors
      return process_already_confirmed_user if @confirmable.confirmed?

      track_invalid_confirmation_token(params[:confirmation_token])

      set_view_variables

      flash[:error] = t('errors.messages.confirmation_invalid_token')
      render :new
    end

    def process_already_confirmed_user
      analytics.track_event(
        Analytics::EMAIL_CONFIRMATION_USER_ALREADY_CONFIRMED, user_id: @confirmable.uuid
      )

      action_text = 'Please sign in.' unless user_signed_in?
      flash[:error] = t('devise.confirmations.already_confirmed', action: action_text)

      redirect_to user_signed_in? ? profile_path : new_user_session_url
    end

    def process_unconfirmed_user
      set_view_variables

      if resource.confirmation_period_expired?
        process_expired_confirmation_token
      else
        process_valid_confirmation_token
      end
    end

    def process_expired_confirmation_token
      analytics.track_event(Analytics::EMAIL_CONFIRMATION_TOKEN_EXPIRED, user_id: @confirmable.uuid)

      flash[:error] = resource.decorate.confirmation_period_expired_error
      render :new
    end

    def process_valid_confirmation_token
      analytics.track_event(Analytics::EMAIL_CONFIRMATION_VALID_TOKEN, user_id: @confirmable.uuid)

      flash.now[:notice] = t('devise.confirmations.confirmed_but_must_set_password')
      render :show
    end

    def after_confirmation_path_for(resource)
      if !user_signed_in?
        new_user_session_url
      elsif resource.two_factor_enabled?
        profile_path
      else
        phone_setup_url
      end
    end

    def process_confirmed_user
      analytics.track_event(Analytics::EMAIL_CHANGED_AND_CONFIRMED, user_id: @confirmable.uuid)
      create_user_event(:email_changed, @confirmable)

      flash[:notice] = t('devise.confirmations.confirmed')
      redirect_to after_confirmation_path_for(@confirmable)
      EmailNotifier.new(@confirmable).send_email_changed_email
    end

    private

    def permitted_params
      params.require(:password_form).
        permit(:confirmation_token, :password)
    end

    def sign_in_and_redirect_user
      sign_in @confirmable
      redirect_to after_confirmation_path_for(@confirmable)
    end

    def track_invalid_confirmation_token(token)
      token ||= 'nil'

      analytics.track_event(Analytics::EMAIL_CONFIRMATION_INVALID_TOKEN, token: token)
    end
  end
end
