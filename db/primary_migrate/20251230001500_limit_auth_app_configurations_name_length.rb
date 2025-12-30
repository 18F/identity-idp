class LimitAuthAppConfigurationsNameLength < ActiveRecord::Migration[8.0]
  def up
    safety_assured do
      execute <<~SQL
        UPDATE auth_app_configurations
        SET name = LEFT(name, 255)
        WHERE LENGTH(name) > 255;
      SQL

      change_column :auth_app_configurations, :name, :string, limit: 255
    end
  end

  def down
    safety_assured do
      change_column :auth_app_configurations, :name, :string
    end
  end
end
