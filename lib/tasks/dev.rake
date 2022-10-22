namespace :dev do
  desc 'Sample data for local development environment'
  task prime: :environment do
    pw = 'salty pickles'
    %w[test1@test.com test2@test.com admin@gsa.gov].each_with_index do |email, index|
      user = User.find_with_email(email) || User.create!
      setup_user(user, email: email, pw: pw, num: index)
    end

    user = User.find_with_email('totp@test.com') || User.create!
    setup_totp_user(user, email: 'totp@test.com', pw: pw)

    ial2_user = User.find_with_email('test2@test.com')
    profile = Profile.new(user: ial2_user)
    pii = Pii::Attributes.new_from_hash(
      ssn: '660-00-1234',
      dob: '1920-01-01',
      first_name: 'Some',
      last_name: 'One',
    )
    personal_key = profile.encrypt_pii(pii, pw)
    profile.verified_at = Time.zone.now
    profile.activate

    Rails.logger.warn "email=#{ial2_user.email} personal_key=#{personal_key}"
  end

  # protip: set SCRYPT_COST env vars to '800$8$1$'
  # or whatever the test env uses, to override config/application.yml
  # before running this task.
  # e.g.
  # rake dev:random_users NUM_USERS=1000 SCRYPT_COST='800$8$1$'

  # some baseline metrics
  # $ rake dev:random_users NUM_USERS=1000 SCRYPT_COST='800$8$1$'
  # Users: 100% |==================================================| Time: 00:00:37
  # $ rake dev:random_users NUM_USERS=100000 SCRYPT_COST='800$8$1$'
  # Users: 100% |==================================================| Time: 01:06:08

  desc 'Create N random User records'
  task random_users: :environment do
    pw = 'salty pickles'
    num_users = (ENV['NUM_USERS'] || 100).to_i
    num_created = 0
    unless ENV['PROGRESS'] == 'no'
      progress = ProgressBar.create(
        title: 'Users',
        total: num_users,
        format: '%t: |%B| %j%% [%a / %e]',
      )
    end

    User.transaction do
      while num_created < num_users
        email_addr = "testuser#{num_created}@example.com"
        user = User.find_with_email(email_addr) || User.create!
        setup_user(user, email: email_addr, pw: pw, num: num_created)

        if ENV['VERIFIED']
          profile = Profile.new(user: user)
          pii = Pii::Attributes.new_from_hash(
            first_name: 'Test',
            last_name: "User #{num_created}",
            dob: '1970-05-01',
            ssn: "666-#{num_created}", # doesn't need to be legit 9 digits, just unique
          )
          personal_key = profile.encrypt_pii(pii, pw)
          profile.verified_at = Time.zone.now
          profile.activate

          Rails.logger.warn "email=#{email_addr} personal_key=#{personal_key}"
        end

        num_created += 1
        progress&.increment
      end
    end
  end

  desc 'Create in-person enrollment records for N random users'
  task enroll_random_users_in_person: :environment do
    num_users = (ENV['NUM_USERS'] || 100).to_i
    # num_created = 0
    unless ENV['PROGRESS'] == 'no'
      progress = ProgressBar.create(
        title: 'Enrollments',
        total: num_users,
        format: '%t: |%B| %j%% [%a / %e]',
      )
    end
    random = Random.new(num_users)
    enrollment_status = InPersonEnrollment.statuses[(ENV['ENROLLMENT_STATUS'] || "pending")]
    enrollments = (0...num_users).map do |n|
      user = User.find_with_email("testuser#{n}@example.com")
      next if user.nil?
      enrollment = {
        user_id: user.id,
        status: enrollment_status,
        unique_id: SecureRandom.hex(9),
        enrollment_established_at: Time.zone.now - random.rand(0..5).days.ago
      }
      progress&.increment
      enrollment
    end
    InPersonEnrollment.create!(enrollments)
  end

  desc 'Create a user with multiple emails and output the emails and passwords'
  task create_multiple_email_user: :environment do
    emails = [
      "testuser#{SecureRandom.hex(8)}@example.com",
      "testuser#{SecureRandom.hex(8)}@example.com",
    ]
    user = User.create!(
      confirmed_at: Time.zone.now,
      confirmation_sent_at: 5.minutes.ago,
      email: emails.first,
      password: 'salty pickles',
      personal_key: RandomPhrase.new(num_words: 4).to_s,
    )
    user.phone_configurations.create!(
      phone_configuration_data(user, num: 1234),
    )
    user.email_addresses.create!(
      confirmed_at: Time.zone.now,
      email: emails.last,
    )
    warn "Emails: #{emails.join(', ')}\nPassword: salty pickles"
  end

  def setup_user(user, args)
    EmailAddress.create!(email: args[:email], user: user, confirmed_at: Time.zone.now)
    user.reset_password(args[:pw], args[:pw])
    MfaContext.new(user).phone_configurations.create(phone_configuration_data(user, args))
    Event.create(user_id: user.id, event_type: :account_created)
  end

  def setup_totp_user(user, args)
    EmailAddress.create!(email: args[:email], user: user, confirmed_at: Time.zone.now)
    user.reset_password(args[:pw], args[:pw])
    Event.create(user_id: user.id, event_type: :account_created)
  end

  def fingerprint(email)
    Pii::Fingerprinter.fingerprint(email)
  end

  def phone_configuration_data(user, args)
    {
      delivery_preference: user.otp_delivery_preference,
      phone: format('+1 (415) 555-%04d', args[:num]),
      confirmed_at: Time.zone.now,
    }
  end
end
