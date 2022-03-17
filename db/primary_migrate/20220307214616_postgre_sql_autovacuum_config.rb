class PostgreSqlAutovacuumConfig < ActiveRecord::Migration[6.1]
  def up
    safety_assured do
      execute <<-SQL
        ALTER TABLE "devices" SET (autovacuum_vacuum_scale_factor = 0.02,
                                   autovacuum_analyze_scale_factor = 0.01,
                                   autovacuum_vacuum_threshold = 0);

        ALTER TABLE "users" SET (autovacuum_vacuum_scale_factor = 0.02,
                                 autovacuum_analyze_scale_factor = 0.01,
                                 autovacuum_vacuum_threshold = 0);
      SQL
    end
  end

  # restores original settings:
  # https://github.com/18F/identity-devops/issues/4175#issuecomment-1062302198
  def down
    safety_assured do
      execute <<-SQL
        ALTER TABLE "devices" RESET (autovacuum_vacuum_scale_factor,
                                     autovacuum_analyze_scale_factor,
                                     autovacuum_vacuum_threshold);

        ALTER TABLE "users" RESET (autovacuum_vacuum_scale_factor,
                                   autovacuum_analyze_scale_factor,
                                   autovacuum_vacuum_threshold);
      SQL
    end
  end
end
