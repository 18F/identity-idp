namespace :db do
  desc 'Raise an error if migrations are pending'
  task check_for_pending_migrations: :environment do
    ActiveRecord::Migration.check_pending!(ActiveRecord::Base.connection)
  end
end
