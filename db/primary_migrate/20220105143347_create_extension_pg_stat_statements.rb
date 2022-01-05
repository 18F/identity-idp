class CreateExtensionPgStatStatements < ActiveRecord::Migration[6.1]
  def up
    enable_extension 'pg_stat_statements' unless extension_enabled?('pg_stat_statements')
  end

  def down
    disable_extension 'pg_stat_statements' if extension_enabled?('pg_stat_statements')
  end
end
