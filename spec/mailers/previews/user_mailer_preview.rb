class UserMailerPreview < ActionMailer::Preview
  def email_confirmation_instructions
    UserMailer.email_confirmation_instructions(
      User.first,
      'foo@bar.gov',
      SecureRandom.hex,
      request_id: SecureRandom.uuid,
      instructions: I18n.t(
        'user_mailer.email_confirmation_instructions.first_sentence.forgot_password',
        app_name: APP_NAME,
      ),
    )
  end

  def unconfirmed_email_instructions
    UserMailer.unconfirmed_email_instructions(
      User.first,
      'foo@bar.gov',
      SecureRandom.hex,
      request_id: SecureRandom.uuid,
      instructions: I18n.t(
        'user_mailer.email_confirmation_instructions.first_sentence.forgot_password',
        app_name: APP_NAME,
      ),
    )
  end

  def signup_with_your_email
    UserMailer.signup_with_your_email(User.first, 'foo@bar.gov')
  end

  def reset_password_instructions
    UserMailer.reset_password_instructions(User.first, 'foo@bar.gov', token: SecureRandom.hex)
  end

  def password_changed
    UserMailer.password_changed(User.first, EmailAddress.first, disavowal_token: SecureRandom.hex)
  end

  def phone_added
    UserMailer.phone_added(User.first, EmailAddress.first, disavowal_token: SecureRandom.hex)
  end

  def account_does_not_exist
    UserMailer.account_does_not_exist('foo@bar.gov', SecureRandom.uuid)
  end

  def personal_key_sign_in
    UserMailer.personal_key_sign_in(User.first, 'foo@bar.gov', disavowal_token: SecureRandom.hex)
  end

  def new_device_sign_in
    UserMailer.new_device_sign_in(
      user: User.first,
      email_address: EmailAddress.first,
      date: 'February 25, 2019 15:02',
      location: 'Washington, DC',
      disavowal_token: SecureRandom.hex,
    )
  end

  def personal_key_regenerated
    UserMailer.personal_key_regenerated(User.first, 'foo@bar.gov')
  end

  def account_reset_request
    UserMailer.account_reset_request(
      User.first, EmailAddress.first, User.first.build_account_reset_request
    )
  end

  def account_reset_granted
    UserMailer.account_reset_granted(
      User.first, EmailAddress.first, User.first.build_account_reset_request
    )
  end

  def account_reset_complete
    UserMailer.account_reset_complete(User.first, EmailAddress.first)
  end

  def account_reset_cancel
    UserMailer.account_reset_cancel(User.first, EmailAddress.first)
  end

  def please_reset_password
    UserMailer.please_reset_password(User.first, 'foo@bar.gov')
  end

  def doc_auth_desktop_link_to_sp
    UserMailer.doc_auth_desktop_link_to_sp(User.first, 'foo@bar.gov', 'Example App', '/')
  end

  def letter_reminder
    UserMailer.letter_reminder(User.first, 'foo@bar.gov')
  end

  def add_email
    UserMailer.add_email(User.first, 'foo@bar.gov', SecureRandom.hex)
  end

  def email_added
    UserMailer.email_added(User.first, 'foo@bar.gov')
  end

  def email_deleted
    UserMailer.email_deleted(User.first, 'foo@bar.gov')
  end

  def add_email_associated_with_another_account
    UserMailer.add_email_associated_with_another_account('foo@bar.gov')
  end

  def sps_over_quota_limit
    UserMailer.sps_over_quota_limit('foo@bar.gov')
  end

  def deleted_user_accounts_report
    UserMailer.deleted_user_accounts_report(
      email: 'foo@bar.gov',
      name: 'my name',
      issuers: %w[issuer1 issuer2],
      data: 'data',
    )
  end

  def account_verified
    UserMailer.account_verified(
      User.first,
      EmailAddress.first,
      date_time: DateTime.now,
      sp_name: 'Example App',
      disavowal_token: SecureRandom.hex,
    )
  end
end
