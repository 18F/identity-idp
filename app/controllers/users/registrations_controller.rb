module Users
  class RegistrationsController < Devise::RegistrationsController
    include PhoneConfirmation

    before_action :confirm_two_factor_authenticated, only: [:edit, :update, :destroy_confirm]
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

    def edit
      @update_user_profile_form = UpdateUserProfileForm.new(resource)
    end

    def update
      @update_user_profile_form = UpdateUserProfileForm.new(resource)

      if @update_user_profile_form.submit(user_params)
        process_successful_update(resource)
      else
        clean_up_passwords resource
        render :edit
      end
    end

    def destroy_confirm
    end

    protected

    def process_successful_update(resource)
      process_updates(resource)
      bypass_sign_in resource
    end

    def process_updates(resource)
      updater = UserFlashUpdater.new(@update_user_profile_form, flash)

      updater.set_flash_message

      if @update_user_profile_form.mobile_changed?
        prompt_to_confirm_mobile(@update_user_profile_form.mobile)
      elsif is_flashing_format?
        EmailNotifier.new(resource).send_password_changed_email
        redirect_to edit_user_registration_url
      end
    end

    def process_successful_creation
      render :verify_email, locals: { email: @register_user_email_form.user.email }
    end

    def disable_account_creation
      redirect_to root_path if AppSetting.registrations_disabled?
    end

    def user_params
      params.require(:update_user_profile_form).
        permit(:mobile, :email, :password, :current_password)
    end

    def track_registration(form)
      return analytics.track_event('Account Created', form.user) unless form.email_taken?

      existing_user = User.find_by_email(form.email)
      analytics.track_event('Registration Attempt with existing email', existing_user)
    end
  end
end
