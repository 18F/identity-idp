namespace :users do
  desc 'Look up a user by email address'
  task lookup_by_email: :environment do |_task, args|
    print 'Enter the email address to look up: '
    email = gets.strip
    user = User.find_with_email(email)
    if user.present?
      puts "uuid: #{user.uuid}"
    else
      puts 'No user found'
    end
  end
end
