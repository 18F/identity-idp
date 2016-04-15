module Users
  class RegistrationsController < Devise::RegistrationsController
    before_action :confirm_two_factor_setup, only: [:edit, :update]
    before_action :confirm_two_factor_authenticated, only: [:edit, :update]
    before_action :confirm_security_questions_setup, only: [:edit, :update]
    prepend_before_action :disable_account_creation, only: [:new, :create]

    include DevisePermittedParameters

    # POST /resource
    def create
      build_resource(sign_up_params)
      resource_saved = resource.save

      link_identity_from_session_data(resource, resource_saved) if sp_data[:provider]
      yield resource if block_given?
      if resource_saved
        ::NewRelic::Agent.increment_metric('Custom/User/Created')
        if resource.active_for_authentication?
          set_flash_message :notice, :signed_up if is_flashing_format?
          sign_up(resource_name, resource)
          respond_with resource, location: after_sign_up_path_for(resource)
        else
          expire_data_after_sign_in!
          process_successful_creation(resource)
        end
      else
        process_errors_for(resource, 'create')
      end
    end

    def update
      yield resource if block_given?
      if update_resource(resource, account_update_params)
        process_successful_update(resource)
      else
        process_errors_for(resource, 'update')
      end
    end

    protected

    def process_successful_update(resource)
      process_updates(resource)
      sign_in resource_name, resource, bypass: true
    end

    def process_updates(resource)
      updater = UserProfileUpdater.new(resource, flash)

      updater.set_flash_message

      if updater.needs_to_confirm_mobile_change?
        process_redirection(resource, updater)
      elsif is_flashing_format?
        redirect_to edit_user_registration_url
        EmailNotifier.new(resource).send_password_changed_email
      end
    end

    def process_redirection(resource, updater)
      # In the scenario where a user update results in mobile and/or email
      # "already taken" errors, we need to directly update the user's
      # unconfirmed_mobile by bypassing validations and callbacks. Otherwise,
      # the user would not be able to access the OTP page due to the logic
      # in TwoFactorAuthenticationController#show
      unless resource.pending_mobile_reconfirmation?
        resource.update_columns(unconfirmed_mobile: resource.changes['mobile'][1])
      end

      updater.send_confirmation_email_if_needed

      resource.send_two_factor_authentication_code unless updater.mobile_already_taken?

      redirect_to user_two_factor_authentication_path
    end

    def process_errors_for(resource, action)
      updater = UserProfileUpdater.new(resource, flash)

      # To prevent discovery of existing emails and phone numbers, we check
      # to see if the only errors are "already taken" errors, and if so, we
      # act as if the user update was successful.
      if updater.attribute_already_taken_and_no_other_errors?
        updater.send_notifications
        return method_from_action(action, resource)
      end

      # Since there are other errors at this point, we need to keep the
      # user on the edit profile page, and show them the errors, minus
      # the "already taken" errors to prevent discovery of existing emails
      # and phone numbers.
      updater.delete_already_taken_errors if updater.attribute_already_taken?

      clean_up_passwords resource
      respond_with resource
    end

    def process_successful_creation(resource)
      if is_flashing_format?
        set_flash_message :notice, :signed_up_but_unconfirmed, email: resource.email
      end

      redirect_to root_path
    end

    def method_from_action(action, resource)
      return process_successful_update(resource) if action == 'update'

      process_successful_creation(resource)
    end

    def disable_account_creation
      redirect_to root_path if AppSetting.registrations_disabled?
    end
  end
end
