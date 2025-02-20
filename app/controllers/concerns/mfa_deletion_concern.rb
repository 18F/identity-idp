# frozen_string_literal: true

module MfaDeletionConcern
  include RememberDeviceConcern

  def handle_successful_mfa_deletion(event_type:)
    create_user_event(event_type)
    revoke_remember_device(current_user)
    event = PushNotification::RecoveryInformationChangedEvent.new(user: current_user)
    PushNotification::HttpPush.deliver(event)
    nil
  end
end
