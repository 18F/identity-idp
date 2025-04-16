# frozen_string_literal: true

namespace :db do
  desc 'Raise an error if migrations are pending'
  task check_for_pending_migrations: :environment do
    require 'identity/hostdata'

    if Identity::Hostdata.instance_role == 'migration'
      warn('Skipping pending migration check on migration instance')
    else
      ActiveRecord::Migration.check_all_pending!
    end
  end
end
