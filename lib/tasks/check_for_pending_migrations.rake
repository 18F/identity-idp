namespace :db do
  desc 'Raise an error if migrations are pending'
  task check_for_pending_migrations: :environment do
    require 'login_gov/hostdata'

    if LoginGov::Hostdata.instance_role == 'migration'
      warn('Skipping pending migration check on migration instance')
    elsif LoginGov::Hostdata.config.dig(:default_attributes, :login_dot_gov, :idp_run_migrations)
      warn('Skipping pending migration check, idp_run_migrations=true')
    else
      ActiveRecord::Migration.check_pending!(ActiveRecord::Base.connection)
    end
  end
end
