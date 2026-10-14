# frozen_string_literal: true

namespace :delegated_access do
  desc 'Load the delegated-access content (agencies with their consent content, service ' \
       'providers approved for delegation, applications and their API URLs) from ' \
       'config/delegated_access.yml; locally that is the linked fixture ' \
       'config/delegated_access.localdev.yml. Also run by db:seed.'
  task seed: :environment do
    DelegatedAccessSeeder.new.run
    Rails.logger.info('delegated_access:seed loaded config/delegated_access.yml')
  end
end
