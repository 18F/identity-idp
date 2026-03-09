# frozen_string_literal: true

module MfaDeletionConcern
  include RememberDeviceConcern

  def handle_successful_mfa_deletion(event_type:)
    _disavowal_event, disavowal_token = create_user_event_with_disavowal(event_type, current_user)
    revoke_remember_device(current_user)
    create_mfa_deleted_email(event_type, disavowal_token)
    event = PushNotification::RecoveryInformationChangedEvent.new(user: current_user)
    PushNotification::HttpPush.deliver(event)
    nil
  end

  private

  def create_mfa_deleted_email(event_name, disavowal_token)
    subject = case event_name
    when :authenticator_disabled
      t('user_mailer.multi_factor_authentication.auth_app_deleted', app_name: APP_NAME)
    when :backup_codes_removed
      t(
        'user_mailer.multi_factor_authentication.backup_codes_deleted',
        app_name: APP_NAME,
      )
    when :phone_removed
      t(
        'user_mailer.multi_factor_authentication.phone_deleted',
        app_name: APP_NAME,
      )
    when :piv_cac_disabled
      t(
        'user_mailer.multi_factor_authentication.piv_card_deleted',
        app_name: APP_NAME,
      )
    when :webauthn_key_removed
      t(
        'user_mailer.multi_factor_authentication.webauthn_deleted',
        app_name: APP_NAME,
      )
    when :webauthn_platform_removed
      t(
        'user_mailer.multi_factor_authentication.webauthn_platform_deleted',
        app_name: APP_NAME,
      )
    end

    current_user.confirmed_email_addresses.each do |email_address|
      UserMailer.with(user: current_user, email_address: email_address)
        .mfa_deleted(subject: subject, disavowal_token: disavowal_token).deliver_now_or_later
    end
  end
end
