namespace :partners do
  desc 'Provision dummy IAL2 users from CSV file'
  task seed_users: :environment do
    options = {
      csv_file: ENV['CSV_FILE'],
      email_domain: ENV['EMAIL_DOMAIN'],
    }

    if options.values.any?(&:nil?)
      puts 'You must define the environment variables CSV_FILE and EMAIL_DOMAIN'
      exit(-1)
    end

    begin
      count = UserSeeder.run(**options)
      puts "#{count} users created"
      puts 'Complete!'
    rescue ArgumentError, StandardError => e
      puts "ERROR: #{e.message}"
      exit(-1)
    end
  end
end
