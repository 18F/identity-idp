module Users
  class RegistrationsController < Devise::RegistrationsController
    include PhoneConfirmation

    before_action :confirm_two_factor_authenticated, only: [:destroy_confirm]
    prepend_before_action :disable_account_creation, only: [:new, :create]

    def start
      analytics.track_event(Analytics::USER_REGISTRATION_INTRO_VISIT)
    end

    def new
      ab_finished(:demo)
      @register_user_email_form = RegisterUserEmailForm.new
      analytics.track_event(Analytics::USER_REGISTRATION_ENTER_EMAIL_VISIT)
    end

    # POST /resource
    def create
      @register_user_email_form = RegisterUserEmailForm.new

      if @register_user_email_form.submit(params[:user])
        process_successful_creation

        track_registration(@register_user_email_form)
      else
        analytics.track_event(
          Analytics::USER_REGISTRATION_INVALID_EMAIL, email: @register_user_email_form.email
        )
        render :new
      end
    end

    def destroy_confirm
    end

    protected

    def process_successful_creation
      @resend_confirmation = params[:user][:resend]

      render :verify_email, locals: { email: @register_user_email_form.user.email }
    end

    def disable_account_creation
      redirect_to root_path if AppSetting.registrations_disabled?
    end

    def track_registration(form)
      if form.email_taken?
        existing_user = User.find_with_email(form.email)
        analytics.track_event(
          Analytics::USER_REGISTRATION_EXISTING_EMAIL, user_id: existing_user.uuid
        )
      else
        user = form.user
        analytics.track_event(Analytics::USER_REGISTRATION_ACCOUNT_CREATED, user_id: user.uuid)
        create_user_event(:account_created, user)
      end
    end
  end
end
