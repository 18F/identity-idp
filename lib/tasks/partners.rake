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

  desc 'Retrieve a list of agency UUIDs given a list of emails and SPs'
  task get_agency_uuids: :environment do
    options = {
      email_file: ENV['EMAIL_FILE'],
      sp_file: ENV['SP_FILE'],
      output: ENV['OUTPUT'],
    }

    if options.values.any?(&:nil?)
      puts 'You must define the environment variables EMAIL_FILE, SP_FILE, and OUTPUT'
      exit(-1)
    end

    begin
      count = UuidReporter.run(**options)
      puts "#{count} users reported"
      puts 'Complete!'
    rescue ArgumentError, StandardError => e
      puts "ERROR: #{e.message}"
      exit(-1)
    end
  end

  desc 'Retrieve a mapping of agency UUIDs to user IDs given an issuer'
  task export_user_ids_to_agency_uuids: :environment do
    options = {
      issuer: ENV['ISSUER'],
      output: ENV['OUTPUT'],
    }

    if options.values.any?(&:nil?)
      puts 'You must define the environment variables ISSUER and OUTPUT'
      exit(-1)
    end

    begin
      count = UserIdToAgencyUuidReporter.run(**options)
      puts "#{count} records exported"
      puts 'Complete!'
    rescue ArgumentError, StandardError => e
      puts "ERROR: #{e.message}"
      exit(-1)
    end
  end
end
