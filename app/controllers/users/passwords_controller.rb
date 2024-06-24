# frozen_string_literal: true

module Users
  class PasswordsController < ApplicationController
    include ReauthenticationRequiredConcern
    include PasswordConcern

    before_action :confirm_two_factor_authenticated
    before_action :capture_password_if_pii_present_but_locked
    before_action :confirm_recently_authenticated_2fa

    def edit
      analytics.edit_password_visit
      @update_user_password_form = UpdateUserPasswordForm.new(current_user)
      @forbidden_passwords = forbidden_passwords
    end

    def update
      @update_user_password_form = UpdateUserPasswordForm.new(current_user, user_session)

      result = @update_user_password_form.submit(user_params)

      analytics.password_changed(**result.to_h)

      if result.success?
        handle_valid_password
      else
        handle_invalid_password
      end
    end

    private

    def capture_password_if_pii_present_but_locked
      return unless current_user.identity_verified? &&
                    !Pii::Cacher.new(current_user, user_session).exists_in_session?
      user_session[:stored_location] = request.url
      redirect_to capture_password_url
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
        redirect_to account_url
      end
    end

    def handle_invalid_password
      # If the form is submitted with a password that's too short (based on
      # our Devise config) but that zxcvbn treats as strong enough, then we
      # need to provide our custom forbidden passwords data that zxcvbn needs,
      # otherwise the JS will throw an exception and the password strength
      # meter will not appear.
      @forbidden_passwords = forbidden_passwords
      render :edit
    end
  end
end
