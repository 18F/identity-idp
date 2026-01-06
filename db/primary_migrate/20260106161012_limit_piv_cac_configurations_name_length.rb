class LimitPivCacConfigurationsNameLength < ActiveRecord::Migration[8.0]
  def up
    safety_assured do
      execute <<~SQL
        UPDATE piv_cac_configurations
        SET name = LEFT(name, 20)
        WHERE LENGTH(name) > 20;
      SQL

      change_column :piv_cac_configurations, :name, :string, limit: 20
    end
  end

  def down
    safety_assured do
      change_column :piv_cac_configurations, :name, :string
    end
  end
end
