namespace :agency_based_uuids do
  desc 'Link Agency Identities'
  task link_agency_identities: :environment do
    Rails.logger = Logger.new(STDOUT)
    LinkAgencyIdentities.new.link
  end

  desc 'Run Report'
  task report: :environment do
    puts 'agency, old_uuid, new_uuid'
    LinkAgencyIdentities.report.each do |row|
      puts "#{row['name']}, #{row['old_uuid']}, #{row['new_uuid']}"
    end
  end
end
