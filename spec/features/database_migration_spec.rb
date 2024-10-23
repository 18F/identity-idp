require 'rails_helper'

# This test file is intended to test that a may migration is safe to run when the old version is
# currently running in the "50/50 state". Unsafe migrations like dropping or renaming columns
# without use of `ignored_columns` can cause exceptions if a column is still being selected.
#
# Example:
#
# Server v1 is running current migrations, and calls "SELECT id, cool_int FROM users WHERE id = ?"
# Server v2 is deployed with a migration that drops the "cool_int" column from the users table.
# When the migration in v2 is run, v1 will begin to raise exceptions because the column is gone.
#
# The test setup here is dependent on running scripts/rollback_new_migrations.rb prior to be
# in the state of running the server with the previous set of migrations. It also disables
# using transactions as migrations cannot necessarily be run in a transactions. Because of this
# this test is tagged with `unsafe_database_migrations: true` and is not run by default.
#
# Using a feature test here is required to have a persistent server running that loads the
# database models across migration runs.

RSpec.configure do |config|
  config.use_transactional_fixtures = false
end

RSpec.feature 'Database migration', unsafe_database_migrations: true do
  it 'Can run database queries' do
    visit test_database_tables_path

    puts 'rolling back'
    ActiveRecord::MigrationContext.new('db/primary_migrate').migrate
    ActiveRecord::MigrationContext.new('db/worker_jobs_migrate').migrate
    puts 'rolled back'

    visit test_database_tables_path
  end
end
