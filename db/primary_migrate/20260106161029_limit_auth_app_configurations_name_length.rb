class LimitAuthAppConfigurationsNameLength < ActiveRecord::Migration[8.0]
  def up
    safety_assured do
      execute <<~SQL
        UPDATE auth_app_configurations
        SET name = LEFT(name, 20)
        WHERE LENGTH(name) > 20;
      SQL

      change_column :auth_app_configurations, :name, :string, limit: 20
    end
  end

  def down
    safety_assured do
      change_column :auth_app_configurations, :name, :string
    end
  end
end
