namespace :dev do
  desc 'Sample data for local development environment'
  task prime: 'db:setup' do
    pw = 'salty pickles'
    %w(test1@test.com test2@test.com).each_with_index do |email, index|
      ee = EncryptedEmail.new_from_email(email)
      User.find_or_create_by!(email_fingerprint: fingerprint(email)) do |user|
        user.encrypted_email = ee.encrypted
        user.skip_confirmation!
        user.reset_password(pw, pw)
        user.phone = format('+1 (415) 555-01%02d', index)
        user.phone_confirmed_at = Time.current
        Event.create(user_id: user.id, event_type: :account_created)
      end
    end

    loa3_user = User.find_by(email_fingerprint: fingerprint('test2@test.com'))
    loa3_user.unlock_user_access_key(pw)
    profile = Profile.new(user: loa3_user)
    pii = Pii::Attributes.new_from_hash(
      ssn: '660-00-1234',
      dob: '1920-01-01',
      first_name: 'Some',
      last_name: 'One'
    )
    recovery_code = profile.encrypt_pii(loa3_user.user_access_key, pii)
    profile.activate

    Kernel.puts "===="
    Kernel.puts "email=#{loa3_user.email} recovery_code=#{recovery_code}"
    Kernel.puts "===="
  end

  def fingerprint(email)
    Pii::Fingerprinter.fingerprint(email)
  end
end
