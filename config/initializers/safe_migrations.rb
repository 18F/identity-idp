require 'deploy/migration_statement_timeout'

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Migration.prepend(Deploy::MigrationStatementTimeout)
end
