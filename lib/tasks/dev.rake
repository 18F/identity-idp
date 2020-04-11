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

    ee = EncryptedAttribute.new_from_decrypted('totp@test.com')
    User.find_or_create_by!(email_fingerprint: ee.fingerprint) do |user|
      setup_totp_user(user, ee: ee, pw: pw)
    end

    ial2_user = User.find_by(email_fingerprint: fingerprint('test2@test.com'))
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

  # some baseline metrics
  # $ rake dev:random_users NUM_USERS=1000 SCRYPT_COST='800$8$1$' ATTRIBUTE_COST='800$8$1$'
  # Users: 100% |==================================================| Time: 00:00:37
  # $ rake dev:random_users NUM_USERS=100000 SCRYPT_COST='800$8$1$' ATTRIBUTE_COST='800$8$1$'
  # Users: 100% |==================================================| Time: 01:06:08

  desc 'Create N random User records'
  task random_users: :environment do
    # split number of users by number of cores
    proc_num = Concurrent.physical_processor_count
    p "#{proc_num} physical cores found\n"

    pool = Concurrent::FixedThreadPool.new(ENV.fetch("CONCURRENCY", 8), fallback_policy: :caller_runs) # default to 4 threads
    # pool = Concurrent::ThreadPoolExecutor.new(max_threads: ENV.fetch("CONCURRENCY", 4))
    (1..10000).each do |user_num|
      pool.post do
        generate_user(user_num)
      end
    end
      # batch_generate_users(100, num)
      # execute the follwing in parallel
  
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

  # rubocop:disable all
  def setup_user(user, args)
    user.encrypted_email = args[:ee].encrypted
    user.reset_password(args[:pw], args[:pw])
    MfaContext.new(user).phone_configurations.create(phone_configuration_data(user, args))
    Event.create(user_id: user.id, event_type: :account_created)
    user.email_addresses.update_all(confirmed_at: Time.zone.now)
  end
  # rubocop:enable all

  def setup_totp_user(user, args)
    user.encrypted_email = args[:ee].encrypted
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

  def generate_user(user_num)
    pw = 'salty pickles'

    User.transaction do
      email_addr = "testuser#{user_num}@example.com"
      ee = EncryptedAttribute.new_from_decrypted(email_addr)
      User.find_or_create_by!(email_fingerprint: ee.fingerprint) do |user|
        setup_user(user, ee: ee, pw: pw, num: user_num)
      end

      if ENV['VERIFIED']
        user = User.find_by(email_fingerprint: ee.fingerprint)
        profile = Profile.new(user: user)
        pii = Pii::Attributes.new_from_hash(
          first_name: 'Test',
          last_name: "User #{user_num}",
          dob: '1970-05-01',
          ssn: "666-#{user_num}", # doesn't need to be legit 9 digits, just unique
        )
        personal_key = profile.encrypt_pii(pii, pw)
        profile.verified_at = Time.zone.now
        profile.activate

        Rails.logger.warn "email=#{email_addr} personal_key=#{personal_key}"  
        progress&.increment
      end
    end
  end

  def batch_generate_users(count=100, proc_num)
    pw = 'salty pickles'
    num_users = count.to_i
    num_created = 0
    unless ENV['PROGRESS'] == 'no'
      progress = ProgressBar.create(
        title: "Users #{proc_num}",
        total: num_users,
        format: '%t: |%B| %j%% [%a / %e]',
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
end
