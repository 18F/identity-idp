namespace :adhoc do
  desc 'Copy phone configurations to the new table'
  task populate_phone_configurations: :environment do
    Rails.logger = Logger.new(STDOUT)
    PopulatePhoneConfigurationsTable.new.call
  end
end
