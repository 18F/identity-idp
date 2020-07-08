namespace :db do
  desc 'Raise an error if migrations are pending'
  task check_for_pending_migrations: :environment do
    require 'login_gov/hostdata'

    if LoginGov::Hostdata.instance_role == 'migration'
      warn('Skipping pending migration check on migration instance')
    else
      ActiveRecord::Migration.check_pending!(ActiveRecord::Base.connection)
    end
  end
end
