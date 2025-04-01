# frozen_string_literal: true

module Users
  class PasswordsController < ApplicationController
    include ReauthenticationRequiredConcern

    before_action :confirm_two_factor_authenticated
    before_action :capture_password_if_pii_present_but_locked
    before_action :confirm_recently_authenticated_2fa

    def edit
      @update_password_presenter = UpdatePasswordPresenter.new(
        user: current_user,
        required_password_change: required_password_change?,
      )
      analytics.edit_password_visit(required_password_change: required_password_change?)
      @update_user_password_form = UpdateUserPasswordForm.new(user: current_user)
    end

    def update
      @update_user_password_form = UpdateUserPasswordForm.new(
        user: current_user,
        user_session: user_session,
        required_password_change: required_password_change?,
      )

      result = @update_user_password_form.submit(user_password_params)
      attempts_api_tracker.logged_in_password_change(
        success: result.success?,
        failure_reason: attempts_api_tracker.parse_failure_reason(result),
      )

      analytics.password_changed(**result)

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

    def required_password_change?
      session[:redirect_to_change_password] == true
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
      elsif required_password_change?
        session.delete(:redirect_to_change_password)
        redirect_to after_sign_in_path_for(current_user)
      else
        redirect_to account_path
      end
    end

    def handle_invalid_password
      # If the form is submitted with a password that's too short (based on
      # our Devise config) but that zxcvbn treats as strong enough, then we
      # need to provide our custom forbidden passwords data that zxcvbn needs,
      # otherwise the JS will throw an exception and the password strength
      # meter will not appear.
      @update_password_presenter = UpdatePasswordPresenter.new(
        user: current_user,
        required_password_change: required_password_change?,
      )
      render :edit
    end

    def send_password_reset_risc_event
      event = PushNotification::PasswordResetEvent.new(user: current_user)
      PushNotification::HttpPush.deliver(event)
    end

    def create_event_and_notify_user_about_password_change
      _event, disavowal_token = create_user_event_with_disavowal(:password_changed)
      UserAlerts::AlertUserAboutPasswordChange.call(current_user, disavowal_token)
    end

    def user_password_params
      params.require(:update_user_password_form).permit(:password, :password_confirmation)
    end
  end
end
