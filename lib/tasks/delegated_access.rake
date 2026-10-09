# frozen_string_literal: true

namespace :delegated_access do
  desc 'Load the fictitious delegated-access fixtures (agencies, service provider, applications ' \
       'and their API URLs) from config/delegated_access.localdev.yml. Refuses prod and staging.'
  task seed: :environment do
    DelegatedAccessSeeder.new.run
    Rails.logger.info('delegated_access:seed loaded config/delegated_access.localdev.yml')
  end
end
