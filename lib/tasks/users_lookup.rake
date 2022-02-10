namespace :users do
  desc 'Look up a user by email address'
  task lookup_by_email: :environment do |_task, args|
    require 'io/console'
    email = STDIN.getpass('Enter the email address to look up (input will be hidden): ')
    user = User.find_with_email(email)
    if user.present?
      puts "uuid: #{user.uuid}"
    else
      puts 'No user found'
    end
  end
end
