class UserMailerPreview < ActionMailer::Preview
  def email_confirmation_instructions
    UserMailer.with(user: user, email_address: email_address_record).
      email_confirmation_instructions(
        SecureRandom.hex,
        request_id: SecureRandom.uuid,
        instructions: I18n.t(
          'user_mailer.email_confirmation_instructions.first_sentence.forgot_password',
          app_name: APP_NAME,
        ),
      )
  end

  def unconfirmed_email_instructions
    UserMailer.with(user: user, email_address: email_address_record).unconfirmed_email_instructions(
      SecureRandom.hex,
      request_id: SecureRandom.uuid,
      instructions: I18n.t(
        'user_mailer.email_confirmation_instructions.first_sentence.forgot_password',
        app_name: APP_NAME,
      ),
    )
  end

  def signup_with_your_email
    UserMailer.with(user: user, email_address: email_address_record).signup_with_your_email
  end

  def reset_password_instructions
    UserMailer.with(user: user, email_address: email_address_record).reset_password_instructions(
      token: SecureRandom.hex,
    )
  end

  def password_changed
    UserMailer.with(user: user, email_address: email_address_record).
      password_changed(disavowal_token: SecureRandom.hex)
  end

  def phone_added
    UserMailer.with(user: user, email_address: email_address_record).
      phone_added(disavowal_token: SecureRandom.hex)
  end

  def personal_key_sign_in
    UserMailer.with(user: user, email_address: email_address_record).
      personal_key_sign_in(disavowal_token: SecureRandom.hex)
  end

  def new_device_sign_in
    UserMailer.with(user: user, email_address: email_address_record).new_device_sign_in(
      date: 'February 25, 2019 15:02',
      location: 'Washington, DC',
      disavowal_token: SecureRandom.hex,
    )
  end

  def personal_key_regenerated
    UserMailer.with(user: user, email_address: email_address_record).personal_key_regenerated
  end

  def account_reset_request
    UserMailer.with(user: user, email_address: email_address_record).account_reset_request(
      user.build_account_reset_request,
    )
  end

  def account_reset_granted
    UserMailer.with(user: user, email_address: email_address_record).account_reset_granted(
      user.build_account_reset_request,
    )
  end

  def account_reset_complete
    UserMailer.with(user: user, email_address: email_address_record).account_reset_complete
  end

  def account_reset_cancel
    UserMailer.with(user: user, email_address: email_address_record).account_reset_cancel
  end

  def please_reset_password
    UserMailer.with(user: user, email_address: email_address_record).please_reset_password
  end

  def doc_auth_desktop_link_to_sp
    UserMailer.with(user: user, email_address: email_address_record).
      doc_auth_desktop_link_to_sp('Example App', '/')
  end

  def letter_reminder
    UserMailer.with(user: user, email_address: email_address_record).letter_reminder
  end

  def add_email
    UserMailer.with(user: user, email_address: email_address_record).add_email(SecureRandom.hex)
  end

  def email_added
    UserMailer.with(user: user, email_address: email_address_record).email_added
  end

  def email_deleted
    UserMailer.with(user: user, email_address: email_address_record).email_deleted
  end

  def add_email_associated_with_another_account
    UserMailer.with(user: user, email_address: email_address_record).
      add_email_associated_with_another_account
  end

  def account_verified
    UserMailer.with(user: user, email_address: email_address_record).account_verified(
      date_time: DateTime.now,
      sp_name: 'Example App',
      disavowal_token: SecureRandom.hex,
    )
  end

  def in_person_completion_survey
    UserMailer.with(user: user, email_address: email_address_record).in_person_completion_survey
  end

  def in_person_deadline_passed
    UserMailer.with(user: user, email_address: email_address_record).in_person_deadline_passed(
      enrollment: in_person_enrollment,
    )
  end

  def in_person_ready_to_verify
    UserMailer.with(user: user, email_address: email_address_record).in_person_ready_to_verify(
      enrollment: in_person_enrollment,
    )
  end

  def in_person_ready_to_verify_reminder
    UserMailer.with(
      user: user,
      email_address: email_address_record,
    ).in_person_ready_to_verify_reminder(
      enrollment: in_person_enrollment,
    )
  end

  def in_person_verified
    UserMailer.with(user: user, email_address: email_address_record).in_person_verified(
      enrollment: in_person_enrollment,
    )
  end

  def in_person_failed
    UserMailer.with(user: user, email_address: email_address_record).in_person_failed(
      enrollment: in_person_enrollment,
    )
  end

  def in_person_failed_fraud
    UserMailer.with(user: user, email_address: email_address_record).in_person_failed_fraud(
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
        service_provider: ServiceProvider.new(
          friendly_name: 'Test Service Provider',
          issuer: SecureRandom.uuid,
        ),
        status_updated_at: Time.zone.now - 1.hour,
        current_address_matches_id: params['current_address_matches_id'] == 'true',
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
