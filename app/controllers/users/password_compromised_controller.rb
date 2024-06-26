# frozen_string_literal: true

module Users
  class PasswordCompromisedController < ApplicationController
    include PasswordConcern
    before_action :confirm_two_factor_authenticated
    before_action :verify_feature_toggle_on

    def show
      session.delete(:redirect_to_change_password)
      @update_user_password_form = UpdateUserPasswordForm.new(current_user)
      @forbidden_passwords = forbidden_passwords
      analytics.user_password_compromised_visited
    end

    def update
      @update_user_password_form = UpdateUserPasswordForm.new(current_user, user_session, true)

      result = @update_user_password_form.submit(user_password_params)
      analytics.password_changed(**result)
      if result.success?
        handle_valid_password
      else
        handle_invalid_password
      end
    end

    def verify_feature_toggle_on
      redirect_to after_sign_in_path_for(current_user) unless
        FeatureManagement.check_password_enabled?
    end

    def handle_valid_password
      send_password_reset_risc_event
      create_event_and_notify_user_about_password_change
      # Changing the password hash terminates the warden session, and bypass_sign_in ensures
      # that the user remains authenticated.
      bypass_sign_in current_user

      flash[:info] = t('notices.password_changed')
      if @update_user_password_form.personal_key.present?
        user_session[:personal_key] = @update_user_password_form.personal_key
        redirect_to manage_personal_key_url
      else
        redirect_to after_sign_in_path_for(current_user)
      end
    end

    def handle_invalid_password
      @forbidden_passwords = forbidden_passwords
      render :show
    end
  end
end
