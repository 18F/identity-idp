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
      sign_in_and_redirect(resource_name, @confirmable)
    end

    def process_user_with_password_errors
      set_view_variables
      render :show
    end

    def process_user_with_confirmation_errors
      set_view_variables
      render :new
    end

    def process_unconfirmed_user
      set_view_variables

      if resource.confirmation_period_expired?
        flash[:error] = UserDecorator.new(resource).confirmation_period_expired_error
        render :new
      else
        set_flash_message :notice, :confirmed
        render :show
      end
    end

    def after_confirmation_path_for(resource_name, _resource)
      if signed_in?(resource_name)
        user_root_path
      else
        new_session_path(resource_name)
      end
    end

    def process_confirmed_user
      set_flash_message :notice, :confirmed
      redirect_to after_confirmation_path_for(resource_name, resource)
      EmailNotifier.new(@confirmable).send_email_changed_email
    end

    private

    def permitted_params
      params.require(:password_form).
        permit(:confirmation_token, :password)
    end
  end
end
