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
        setup_user(user, email: email_addr, pw: pw, num: num_created) unless user.confirmed?

        if ENV['VERIFIED'] && user.active_profile.nil?
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

  desc 'Create in-person enrollments for N random users'
  task random_in_person_users: [:environment, :random_users] do
    usps_request_delay_ms = (ENV['USPS_REQUEST_DELAY_MS'] || 0).to_i
    num_users = (ENV['NUM_USERS'] || 100).to_i
    pw = 'salty pickles'
    unless ENV['PROGRESS'] == 'no'
      progress = ProgressBar.create(
        title: 'Enrollments',
        total: num_users,
        format: '%t: |%B| %j%% [%a / %e]',
      )
    end
    random = Random.new(num_users)
    raw_enrollment_status = (ENV['ENROLLMENT_STATUS'] || 'pending')
    enrollment_status = InPersonEnrollment.statuses[raw_enrollment_status]
    is_established = ['pending', 'passed', 'failed', 'expired'].include?(raw_enrollment_status)

    create_in_usps = !!ENV['CREATE_PENDING_ENROLLMENT_IN_USPS']

    InPersonEnrollment.transaction do
      (0...num_users).each do |n|
        email_addr = "testuser#{n}@example.com"
        user = User.find_with_email(email_addr)
        next if user.nil?
        if is_established
          unless raw_enrollment_status == 'pending' && !user.pending_in_person_enrollment.nil?
            profile = Profile.new(user: user)

            # Convert index to a string of letters to be a valid last name for the USPS API
            usps_compatible_number_alternative = n.to_s.chars.map do |c|
              ('a'.ord + c.to_i).chr
            end.join('')

            pii = Pii::Attributes.new_from_hash(
              first_name: 'Test',
              last_name: "User #{usps_compatible_number_alternative}",
              dob: '1970-05-01',
              ssn: "666-#{n}", # doesn't need to be legit 9 digits, just unique
              address1: '1200 FORESTVILLE DR',
              city: 'GREAT FALLS',
              state: 'VA',
              zipcode: '22066',
            )
            personal_key = profile.encrypt_pii(pii, pw)

            if raw_enrollment_status === 'pending' && create_in_usps
              enrollment = InPersonEnrollment.find_or_initialize_by(
                user: user,
                status: :establishing,
                profile: profile,
              )
              enrollment.save!

              success = false
              num_attempts = 0
              max_attempts = (ENV['MAX_NUM_ATTEMPTS'] || 3).to_i
              until success || num_attempts >= max_attempts
                num_attempts += 1
                begin
                  UspsInPersonProofing::EnrollmentHelper.schedule_in_person_enrollment(
                    user,
                    pii,
                  )
                rescue StandardError => e
                  Rails.logger.error 'Exception raised while enrolling user: ' + e.message
                  raise e if num_attempts == max_attempts
                else
                  success = true
                end
                Kernel.sleep(usps_request_delay_ms / 1000.0) if usps_request_delay_ms
              end
            else
              enrollment = InPersonEnrollment.create!(
                user: user,
                profile: profile,
                status: enrollment_status,
                enrollment_established_at: Time.zone.now - random.rand(0..5).days,
                unique_id: SecureRandom.hex(9),
                enrollment_code: SecureRandom.hex(16),
              )

              enrollment.profile.activate if raw_enrollment_status == 'passed'
            end
            Rails.logger.warn "email=#{email_addr} personal_key=#{personal_key}"
          end
        else
          InPersonEnrollment.create!(
            user: user,
            status: enrollment_status,
          )
        end
        progress&.increment
      end
    end
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
