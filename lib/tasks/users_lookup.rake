namespace :users do
  desc 'Look up a user by email address'
  task lookup_by_email: :environment do |_task, args|
    require 'io/console'
    STDOUT.sync = true
    print 'Enter the name of the investigator: '
    investigator_name = STDIN.gets.chomp
    print 'Enter the issue/ticket/reason for the investigation: '
    investigation_number = STDIN.gets.chomp
    email = STDIN.getpass('Enter the email address to look up (input will be hidden): ')
    puts "investigator name: #{investigator_name}"
    puts "investigation reason: #{investigation_number}"
    user = User.find_with_email(email)
    if user.present?
      puts "uuid: #{user.uuid}"
    else
      puts 'uuid: Not Found'
    end
  end
end
