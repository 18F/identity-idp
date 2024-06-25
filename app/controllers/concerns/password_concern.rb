# frozen_string_literal: true

module PasswordConcern
  extend ActiveSupport::Concern

  def send_password_reset_risc_event
    event = PushNotification::PasswordResetEvent.new(user: current_user)
    PushNotification::HttpPush.deliver(event)
  end

  def create_event_and_notify_user_about_password_change
    _event, disavowal_token = create_user_event_with_disavowal(:password_changed)
    UserAlerts::AlertUserAboutPasswordChange.call(current_user, disavowal_token)
  end

  def forbidden_passwords
    current_user.email_addresses.flat_map do |email_address|
      ForbiddenPasswords.new(email_address.email).call
    end
  end

  def user_password_params
    params.require(:update_user_password_form).permit(:password, :password_confirmation)
  end
end
