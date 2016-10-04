namespace :dev do
  desc 'Sample data for local development environment'
  task prime: 'db:setup' do
    %w(test1@test.com test2@test.com).each_with_index do |email, index|
      User.find_or_create_by!(email: email) do |user|
        user.skip_confirmation!
        user.reset_password('password', 'password')
        user.phone = format('+1 (415) 555-01%02d', index)
        user.phone_confirmed_at = Time.current
        Event.create(user_id: user.id, event_type: :account_created)
      end
    end
  end
end
