module Users
  class RegistrationsController < Devise::RegistrationsController
    before_action :confirm_two_factor_authenticated, only: [:edit, :update]
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

        ::NewRelic::Agent.increment_metric('Custom/User/Created')
      else
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

    protected

    def process_successful_update(resource)
      process_updates(resource)
      sign_in resource_name, resource, bypass: true
    end

    def process_updates(resource)
      updater = UserFlashUpdater.new(resource, flash)

      updater.set_flash_message

      if updater.needs_to_confirm_mobile_change?
        process_redirection(resource)
      elsif is_flashing_format?
        redirect_to edit_user_registration_url
        EmailNotifier.new(resource).send_password_changed_email
      end
    end

    def process_redirection(resource)
      resource.send_new_otp unless @update_user_profile_form.mobile_taken?

      redirect_to user_two_factor_authentication_path
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
  end
end
