# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/dev.rake, and they will automatically be available to Rake.

require File.expand_path('../config/application', __FILE__)

Rails.application.load_tasks
Knapsack.load_tasks if defined?(Knapsack)

# Sequent requires a `SEQUENT_ENV` environment to be set
# next to a `RAILS_ENV`
ENV['SEQUENT_ENV'] = ENV['RAILS_ENV'] ||= 'development'

require 'sequent/rake/migration_tasks'

Sequent::Rake::MigrationTasks.new.register_tasks!

# The dependency of sequent:init on :environment ensures the Rails app is loaded
# when running the sequent migrations. This is needed otherwise
# the sequent initializer - which is required to run these rake tasks -
# doesn't run
task 'sequent:init' => [:environment]
task 'sequent:migrate:init' => [:sequent_db_connect]

task 'sequent_db_connect' => :environment do
  Sequent::Support::Database.connect!(ENV['SEQUENT_ENV'])
end

# Create custom rake task setting the SEQUENT_MIGRATION_SCHEMAS for
# running the Rails migrations
task migrate_public_schema: :environment do
  ENV['SEQUENT_MIGRATION_SCHEMAS'] = 'public'
  Rake::Task['db:migrate:primary'].invoke
  ENV['SEQUENT_MIGRATION_SCHEMAS'] = nil
end

# Prevent rails db:migrate:primary from being executed directly.
Rake::Task['db:migrate:primary'].enhance([:'sequent:db:dont_use_db_migrate_directly'])
