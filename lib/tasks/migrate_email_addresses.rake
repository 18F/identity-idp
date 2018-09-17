namespace :adhoc do
  desc 'Copy email addresses to the new table'
  task populate_email_addresses: :environment do
    Rails.logger = Logger.new(STDOUT)
    PopulateEmailAddressesTable.new.call
  end
end
