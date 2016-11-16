namespace :dev do
  desc 'Sample data for local development environment'
  task prime: 'db:setup' do
    pw = 'salty pickles'
    %w(test1@test.com test2@test.com).each_with_index do |email, index|
      User.find_or_create_by!(email: email) do |user|
        user.skip_confirmation!
        user.reset_password(pw, pw)
        user.phone = format('+1 (415) 555-01%02d', index)
        user.phone_confirmed_at = Time.current
        Event.create(user_id: user.id, event_type: :account_created)
      end
    end

    loa3_user = User.find_by(email: 'test2@test.com')
    loa3_user.unlock_user_access_key(pw)
    profile = Profile.new(user: loa3_user)
    pii = Pii::Attributes.new_from_hash(
      ssn: '660-00-1234',
      dob: '1920-01-01',
      first_name: 'Some',
      last_name: 'One'
    )
    profile.encrypt_pii(loa3_user.user_access_key, pii)
    profile.activate
  end
end
