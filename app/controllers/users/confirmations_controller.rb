module Users
  class ConfirmationsController < Devise::ConfirmationsController
    include ValidEmailParameter

    # PATCH /confirm
    def confirm
      with_unconfirmed_confirmable do
        if @password_form.submit(permitted_params)
          do_confirm
        else
          process_user_with_password_errors
        end
      end
    end

    # GET /resource/confirmation?confirmation_token=abcdef
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
      @confirmable = User.find_or_initialize_with_error_by(
        :confirmation_token, params[:confirmation_token]
      )

      if @confirmable.confirmed?
        @confirmable = User.confirm_by_token(params[:confirmation_token])
      end

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
      ::NewRelic::Agent.increment_metric('Custom/User/Confirmed')
      sign_in_and_redirect_user
    end

    def process_user_with_password_errors
      set_view_variables
      render :show
    end

    def process_user_with_confirmation_errors
      return process_already_confirmed_user if @confirmable.confirmed?

      set_view_variables
      render :new
    end

    def process_already_confirmed_user
      action_text = 'Please sign in.' unless user_signed_in?
      flash[:error] = t('devise.confirmations.already_confirmed', action: action_text)

      redirect_to user_signed_in? ? dashboard_index_url : new_user_session_url
    end

    def process_unconfirmed_user
      set_view_variables

      if resource.confirmation_period_expired?
        flash[:error] = UserDecorator.new(resource).confirmation_period_expired_error
        render :new
      else
        flash.now[:notice] = t('devise.confirmations.confirmed_but_must_set_password')
        render :show
      end
    end

    def after_confirmation_path_for(resource)
      if !user_signed_in?
        new_user_session_url
      elsif resource.two_factor_enabled?
        dashboard_index_url
      else
        users_otp_url
      end
    end

    def process_confirmed_user
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
  end
end
