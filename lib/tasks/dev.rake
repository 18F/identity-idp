namespace :dev do
  desc 'Sample data for local development environment'
  task prime: :environment do
    pw = 'salty pickles'
    %w[test1@test.com test2@test.com].each_with_index do |email, index|
      ee = EncryptedAttribute.new_from_decrypted(email)
      User.find_or_create_by!(email_fingerprint: ee.fingerprint) do |user|
        setup_user(user, ee: ee, pw: pw, num: index)
      end
    end

    loa3_user = User.find_by(email_fingerprint: fingerprint('test2@test.com'))
    profile = Profile.new(user: loa3_user)
    pii = Pii::Attributes.new_from_hash(
      ssn: '660-00-1234',
      dob: '1920-01-01',
      first_name: 'Some',
      last_name: 'One'
    )
    personal_key = profile.encrypt_pii(pii, pw)
    profile.verified_at = Time.zone.now
    profile.activate

    Rails.logger.warn "email=#{loa3_user.email} personal_key=#{personal_key}"
  end

  # protip: set ATTRIBUTE_COST and SCRYPT_COST env vars to '800$8$1$'
  # or whatever the test env uses, to override config/application.yml
  # before running this task.
  # e.g.
  # rake dev:random_users NUM_USERS=1000 SCRYPT_COST='800$8$1$' ATTRIBUTE_COST='800$8$1$'

  # some baseline metrics
  # $ rake dev:random_users NUM_USERS=1000 SCRYPT_COST='800$8$1$' ATTRIBUTE_COST='800$8$1$'
  # Users: 100% |==================================================| Time: 00:00:37
  # $ rake dev:random_users NUM_USERS=100000 SCRYPT_COST='800$8$1$' ATTRIBUTE_COST='800$8$1$'
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
        format: '%t: |%B| %j%% [%a / %e]'
      )
    end

    User.transaction do
      while num_created < num_users
        email_addr = "testuser#{num_created}@example.com"
        ee = EncryptedAttribute.new_from_decrypted(email_addr)
        User.find_or_create_by!(email_fingerprint: ee.fingerprint) do |user|
          setup_user(user, ee: ee, pw: pw, num: num_created)
        end

        if ENV['VERIFIED']
          user = User.find_by(email_fingerprint: ee.fingerprint)
          profile = Profile.new(user: user)
          pii = Pii::Attributes.new_from_hash(
            first_name: 'Test',
            last_name: "User #{num_created}",
            dob: '1970-05-01',
            ssn: "666-#{num_created}" # doesn't need to be legit 9 digits, just unique
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

  def setup_user(user, args)
    user.encrypted_email = args[:ee].encrypted
    user.skip_confirmation!
    user.reset_password(args[:pw], args[:pw])
    user.phone = format('+1 (415) 555-%04d', args[:num])
    user.phone_confirmed_at = Time.zone.now
    Event.create(user_id: user.id, event_type: :account_created)
  end

  def fingerprint(email)
    Pii::Fingerprinter.fingerprint(email)
  end
end
