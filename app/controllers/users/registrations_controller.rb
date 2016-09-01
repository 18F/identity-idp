module Users
  class RegistrationsController < Devise::RegistrationsController
    include PhoneConfirmation

    before_action :confirm_two_factor_authenticated, only: [:destroy_confirm]
    prepend_before_action :disable_account_creation, only: [:new, :create]

    def start
    end

    def new
      ab_finished(:demo)
      @register_user_email_form = RegisterUserEmailForm.new
    end

    # POST /resource
    def create
      @register_user_email_form = RegisterUserEmailForm.new

      if @register_user_email_form.submit(params[:user])
        process_successful_creation

        track_registration(@register_user_email_form)
      else
        analytics.track_anonymous_event(
          'User Registration: invalid email', @register_user_email_form.email
        )
        render :new
      end
    end

    def destroy_confirm
    end

    protected

    def process_successful_creation
      render :verify_email, locals: { email: @register_user_email_form.user.email }
    end

    def disable_account_creation
      redirect_to root_path if AppSetting.registrations_disabled?
    end

    def track_registration(form)
      if form.email_taken?
        existing_user = User.find_by_email(form.email)
        analytics.track_event('Registration Attempt with existing email', existing_user)
      else
        user = form.user
        analytics.track_event('Account Created', user)
        create_user_event(:account_created, user)
      end
    end
  end
end
