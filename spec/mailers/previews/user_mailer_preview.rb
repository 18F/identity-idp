class UserMailerPreview < ActionMailer::Preview
  def email_confirmation_instructions
    UserMailer.email_confirmation_instructions(
      user,
      email_address,
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
      user,
      email_address,
      SecureRandom.hex,
      request_id: SecureRandom.uuid,
      instructions: I18n.t(
        'user_mailer.email_confirmation_instructions.first_sentence.forgot_password',
        app_name: APP_NAME,
      ),
    )
  end

  def signup_with_your_email
    UserMailer.signup_with_your_email(user, email_address)
  end

  def reset_password_instructions
    UserMailer.reset_password_instructions(user, email_address, token: SecureRandom.hex)
  end

  def password_changed
    UserMailer.password_changed(user, email_address_record, disavowal_token: SecureRandom.hex)
  end

  def phone_added
    UserMailer.phone_added(user, email_address_record, disavowal_token: SecureRandom.hex)
  end

  def account_does_not_exist
    UserMailer.account_does_not_exist(email_address, SecureRandom.uuid)
  end

  def personal_key_sign_in
    UserMailer.personal_key_sign_in(user, email_address, disavowal_token: SecureRandom.hex)
  end

  def new_device_sign_in
    UserMailer.new_device_sign_in(
      user: user,
      email_address: email_address_record,
      date: 'February 25, 2019 15:02',
      location: 'Washington, DC',
      disavowal_token: SecureRandom.hex,
    )
  end

  def personal_key_regenerated
    UserMailer.personal_key_regenerated(user, email_address)
  end

  def account_reset_request
    UserMailer.account_reset_request(
      user, email_address_record, user.build_account_reset_request
    )
  end

  def account_reset_granted
    UserMailer.account_reset_granted(
      user, email_address_record, user.build_account_reset_request
    )
  end

  def account_reset_complete
    UserMailer.account_reset_complete(user, email_address_record)
  end

  def account_reset_cancel
    UserMailer.account_reset_cancel(user, email_address_record)
  end

  def please_reset_password
    UserMailer.please_reset_password(user, email_address)
  end

  def doc_auth_desktop_link_to_sp
    UserMailer.doc_auth_desktop_link_to_sp(user, email_address, 'Example App', '/')
  end

  def letter_reminder
    UserMailer.letter_reminder(user, email_address)
  end

  def add_email
    UserMailer.add_email(user, email_address, SecureRandom.hex)
  end

  def email_added
    UserMailer.email_added(user, email_address)
  end

  def email_deleted
    UserMailer.email_deleted(user, email_address)
  end

  def add_email_associated_with_another_account
    UserMailer.add_email_associated_with_another_account(email_address)
  end

  def sps_over_quota_limit
    UserMailer.sps_over_quota_limit(email_address)
  end

  def deleted_user_accounts_report
    UserMailer.deleted_user_accounts_report(
      email: email_address,
      name: 'my name',
      issuers: %w[issuer1 issuer2],
      data: 'data',
    )
  end

  def account_verified
    UserMailer.account_verified(
      user,
      email_address_record,
      date_time: DateTime.now,
      sp_name: 'Example App',
      disavowal_token: SecureRandom.hex,
    )
  end

  def in_person_ready_to_verify
    UserMailer.in_person_ready_to_verify(
      user,
      email_address_record,
      first_name: 'Michael',
      enrollment: in_person_enrollment,
    )
  end

  def in_person_verified
    UserMailer.in_person_verified(
      user,
      email_address_record,
      enrollment: in_person_enrollment,
    )
  end

  def in_person_failed
    UserMailer.in_person_failed(
      user,
      email_address_record,
      enrollment: in_person_enrollment,
    )
  end

  private

  def user
    unsaveable(User.new(email_addresses: [email_address_record]))
  end

  def email_address
    'email@example.com'
  end

  def email_address_record
    unsaveable(EmailAddress.new(email: email_address))
  end

  def in_person_enrollment
    unsaveable(
      InPersonEnrollment.new(
        user: user,
        profile: unsaveable(Profile.new(user: user)),
        enrollment_code: '2048702198804358',
        created_at: Time.zone.now - 2.hours,
        status_updated_at: Time.zone.now - 1.hour,
        current_address_matches_id: true,
        selected_location_details: {
          'name' => 'BALTIMORE',
          'street_address' => '900 E FAYETTE ST RM 118',
          'formatted_city_state_zip' => 'BALTIMORE, MD 21233-9715',
          'phone' => '555-123-6409',
          'weekday_hours' => '8:30 AM - 4:30 PM',
          'saturday_hours' => '9:00 AM - 12:00 PM',
          'sunday_hours' => 'Closed',
        },
      ),
    )
  end

  # Remove #save and #save! to make sure we can't write these made-up records
  def unsaveable(record)
    class << record
      def save
        raise "don't save me!"
      end

      def save!
        raise "don't save me!"
      end
    end

    record
  end
end
